import 'package:split_bill_app/services/analytics_service.dart';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import 'bill_flow/bill_calculator.dart' show minorFromAny;
import 'config/feature_costs.dart';
import 'domain/money.dart' show fromMinorUnits, normalizeCurrency;
import 'helpers/rewarded_ad_helper.dart';
import 'manual_entry_screen.dart';
import 'providers/app_settings_provider.dart';
import 'screens/scan_receipt/amount_input.dart';
import 'screens/scan_receipt/review_banner_content.dart'
    show kReviewConfidenceThreshold;
import 'screens/scan_receipt/review_totals.dart';
import 'screens/scan_receipt/scan_error_content.dart';
import 'screens/scan_receipt/widgets/no_points_dialog.dart';
import 'screens/scan_receipt/widgets/scan_empty_state.dart';
import 'screens/scan_receipt/widgets/scan_error_card.dart';
import 'screens/scan_receipt/widgets/scan_reading_view.dart';
import 'screens/scan_receipt/widgets/scan_top_bar.dart';
import 'services/receipt_service.dart';
import 'services/revenue_cat_service.dart';
import 'split_bill_screen.dart';
import 'theme/theme.dart';
import 'widgets/feedback/feedback.dart';
import 'widgets/receipt_result_view.dart';

enum _ScanPhase { idle, reading, saving, review }

class ScanReceiptScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? participants;
  final String? billId; // For resuming

  /// Group the finished bill is filed into (data contract `groupId`).
  final String? groupId;
  final String? initialLocalImagePath; // For resuming

  const ScanReceiptScreen({
    super.key,
    this.participants,
    this.groupId,
    this.billId,
    this.initialLocalImagePath,
  });

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final ReceiptService _receiptService = ReceiptService();
  final ImagePicker _picker = ImagePicker();

  File? _image;
  _ScanPhase _phase = _ScanPhase.idle;
  Map<String, dynamic>? _receiptData;

  /// The last failure, shown as a card on the start screen.
  ScanErrorContent? _error;

  /// Bumped on every attempt and on Cancel, so a late answer from a
  /// cancelled read is ignored.
  int _attempt = 0;

  // Editing state
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _serviceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _tipController = TextEditingController();
  final TextEditingController _deliveryController = TextEditingController();

  List<Map<String, TextEditingController>> _itemControllers = [];

  bool get _busy => _phase == _ScanPhase.reading || _phase == _ScanPhase.saving;

  String get _currency {
    final code = _receiptData?['currency_code']?.toString();
    if (code != null && code.trim().isNotEmpty) return normalizeCurrency(code);
    return normalizeCurrency(context.read<AppSettingsProvider>().currencyCode);
  }

  @override
  void initState() {
    super.initState();
    RewardedAdHelper.warmUpIfEligible();
    if (widget.initialLocalImagePath != null) {
      _loadSavedImage();
    }
  }

  Future<void> _loadSavedImage() async {
    final file = File(widget.initialLocalImagePath!);
    if (await file.exists()) {
      if (!mounted) return;
      setState(() => _image = file);
    }
  }

  @override
  void dispose() {
    _restaurantController.dispose();
    _taxController.dispose();
    _serviceController.dispose();
    _discountController.dispose();
    _tipController.dispose();
    _deliveryController.dispose();
    _disposeItemControllers();
    super.dispose();
  }

  void _disposeItemControllers() {
    for (final controllers in _itemControllers) {
      controllers['name']?.dispose();
      controllers['qty']?.dispose();
      controllers['price']?.dispose();
    }
    _itemControllers = [];
  }

  // ------------------------------------------------------ snap and save

  Future<void> _handleSnapAndSave() async {
    if (_image == null) {
      if (_busy) return;
      try {
        final XFile? photo = await _picker.pickImage(
          source: kDebugMode ? ImageSource.gallery : ImageSource.camera,
        );
        if (photo != null) {
          setState(() {
            _image = File(photo.path);
            _receiptData = null;
          });
          await _saveForLater();
        }
      } catch (e) {
        debugPrint('Error picking image: $e');
        _showPickError(e);
      }
    } else {
      await _saveForLater();
    }
  }

  Future<void> _saveForLater() async {
    if (_image == null) return;
    setState(() => _phase = _ScanPhase.saving);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Save image locally.
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await _image!.copy('${directory.path}/$fileName');

      // Participants' uids, for querying.
      final participantUids = <String>[user.uid]; // Host always included.
      if (widget.participants != null) {
        for (final p in widget.participants!) {
          if (p.containsKey('uid') && p['uid'] != null) {
            participantUids.add(p['uid']);
          } else if (p.containsKey('id') && p['id'] != null) {
            participantUids.add(p['id']);
          }
        }
      }

      // 2. Create or update the bill document.
      final billData = {
        'hostId': user.uid,
        'hostName': user.displayName ?? 'host'.tr(),
        'participants': widget.participants ?? [],
        'participants_uids': participantUids,
        'date': Timestamp.fromDate(_selectedDate),
        'status': 'UNATTEMPTED',
        'localImagePath': savedImage.path,
        'storeName': 'unattempted_receipt'.tr(),
        'items': [],
        'charges': {},
        'groupId': ?widget.groupId,
      };

      if (widget.billId != null) {
        await FirebaseFirestore.instance
            .collection('bills')
            .doc(widget.billId)
            .update(billData);
      } else {
        await FirebaseFirestore.instance.collection('bills').add(billData);
      }

      if (mounted) {
        AppToast.show(
          context,
          message: 'saved_for_later'.tr(),
          type: AppToastType.success,
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('Error saving for later: $e');
      if (mounted) {
        AppToast.show(
          context,
          message: 'bf_scan_err_save'.tr(),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _phase = _ScanPhase.idle);
    }
  }

  Future<void> _deleteSavedDraft() async {
    final billId = widget.billId;
    if (billId == null) return;
    final previous = _phase;
    setState(() => _phase = _ScanPhase.saving);

    try {
      final localImagePath =
          widget.initialLocalImagePath ??
          _image?.path ??
          _receiptData?['localImagePath'];
      if (localImagePath is String && localImagePath.isNotEmpty) {
        final file = File(localImagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await FirebaseFirestore.instance.collection('bills').doc(billId).delete();

      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bill_deleted'.tr(),
        type: AppToastType.success,
      );
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('Error deleting draft: $e');
      if (!mounted) return;
      setState(() => _phase = previous);
      AppToast.show(
        context,
        message: 'bf_scan_err_delete'.tr(),
        type: AppToastType.error,
      );
    }
  }

  Future<void> _confirmDeleteSavedDraft() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final p = dialogContext.palette;
        return AlertDialog(
          backgroundColor: p.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.cardRadius,
          ),
          title: Text('delete_saved_draft'.tr()),
          content: Text('delete_saved_draft_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('common_cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: p.error,
                foregroundColor: p.onError,
              ),
              child: Text('common_delete'.tr()),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      AppHaptics.warning();
      await _deleteSavedDraft();
    }
  }

  // ------------------------------------------------------ review editing

  void _initializeControllers() {
    final data = _receiptData;
    if (data == null) return;
    _disposeItemControllers();
    final currency = _currency;

    String amountText(Object? raw) {
      final minor = minorFromAny(raw, currency);
      return minor == 0 ? '' : minorToInputText(minor, currency);
    }

    _restaurantController.text = data['restaurant_name']?.toString() ?? '';
    _taxController.text = amountText(data['tax_amount']);
    _serviceController.text = amountText(data['service_charge']);
    _discountController.text = amountText(data['discount_amount']);
    _tipController.text = amountText(data['tip_amount']);
    _deliveryController.text = amountText(data['delivery_fee']);

    _itemControllers = [
      for (final raw in (data['items'] as List? ?? const []))
        if (raw is Map)
          {
            'name': TextEditingController(text: raw['name']?.toString() ?? ''),
            'qty': TextEditingController(
              text:
                  '${parseQuantityInput('${raw['qty'] ?? raw['quantity'] ?? 1}') ?? 1}',
            ),
            'price': TextEditingController(
              text: minorToInputText(
                raw['priceMinor'] is num
                    ? (raw['priceMinor'] as num).round()
                    : minorFromAny(raw['price'] ?? raw['unit_price'], currency),
                currency,
              ),
            ),
          },
    ];
    _recomputeTotals();
  }

  ReviewChargeTexts get _chargeTexts => (
    tax: _taxController.text,
    service: _serviceController.text,
    tip: _tipController.text,
    delivery: _deliveryController.text,
    discount: _discountController.text,
  );

  /// Totals in minor units from the fields, written back as legacy doubles.
  void _recomputeTotals() {
    final data = _receiptData;
    if (data == null) return;
    final draft = buildReviewDraft(
      receiptData: data,
      currency: _currency,
      lines: [
        for (final c in _itemControllers)
          (name: c['name']!.text, qty: c['qty']!.text, price: c['price']!.text),
      ],
      charges: _chargeTexts,
    );
    writeReviewTotals(data, draft);
  }

  double _confidenceValue(dynamic rawValue, {double fallback = 0.92}) {
    if (rawValue is num) {
      return rawValue.clamp(0.0, 1.0).toDouble();
    }
    return fallback;
  }

  double _averageScores(Iterable<double> values, {double fallback = 1.0}) {
    final scores = values.toList();
    if (scores.isEmpty) return fallback;
    return scores.reduce((left, right) => left + right) / scores.length;
  }

  bool _didItemChange(
    Map<String, dynamic> originalItem, {
    required String name,
    required int qty,
    required int priceMinor,
    required String currency,
  }) {
    final originalName = (originalItem['name'] ?? '').toString().trim();
    final originalQty = parseQuantityInput('${originalItem['qty'] ?? 1}') ?? 1;
    final originalPrice = originalItem['priceMinor'] is num
        ? (originalItem['priceMinor'] as num).round()
        : minorFromAny(
            originalItem['price'] ?? originalItem['unit_price'],
            currency,
          );
    return originalName != name ||
        originalQty != qty ||
        originalPrice != priceMinor;
  }

  void _saveChanges() {
    final data = _receiptData;
    if (data == null) return;
    final currency = _currency;
    setState(() {
      data['restaurant_name'] = _restaurantController.text.trim();
      data['date'] = _selectedDate.toString();
      final originalItems = [
        for (final item in (data['items'] as List? ?? const []))
          if (item is Map) Map<String, dynamic>.from(item),
      ];

      final updatedItems = <Map<String, dynamic>>[];
      final updatedItemScores = <double>[];
      for (int index = 0; index < _itemControllers.length; index++) {
        final controllers = _itemControllers[index];
        final name = controllers['name']!.text.trim();
        if (name.isEmpty) continue;
        final qty = parseQuantityInput(controllers['qty']!.text) ?? 1;
        final priceMinor =
            parseMinorInput(controllers['price']!.text, currency) ?? 0;
        final originalItem = index < originalItems.length
            ? originalItems[index]
            : <String, dynamic>{};
        final wasEdited =
            originalItem.isEmpty ||
            _didItemChange(
              originalItem,
              name: name,
              qty: qty,
              priceMinor: priceMinor,
              currency: currency,
            );
        final confidenceScore = wasEdited
            ? 1.0
            : _confidenceValue(originalItem['confidence_score']);
        final confidenceNote = wasEdited
            ? ''
            : (originalItem['confidence_note']?.toString() ?? '');
        final reviewStatus = wasEdited
            ? 'confirmed'
            : (originalItem['review_status']?.toString().trim().isNotEmpty ==
                      true
                  ? originalItem['review_status'].toString().trim()
                  : (confidenceScore < kReviewConfidenceThreshold
                        ? 'review'
                        : 'confident'));

        updatedItems.add({
          ...originalItem,
          'name': name,
          'qty': qty,
          'price': fromMinorUnits(priceMinor, currency),
          'priceMinor': priceMinor,
          'line_total': fromMinorUnits(priceMinor * qty, currency),
          'confidence_score': confidenceScore,
          'confidence_note': confidenceNote,
          'review_status': reviewStatus,
          if (wasEdited) 'needs_review': false,
        });
        updatedItemScores.add(confidenceScore);
      }
      data['items'] = updatedItems;

      final updatedConfidence = Map<String, dynamic>.from(
        data['confidence_scores'] ?? const {},
      );
      final subtotalScore = _averageScores(updatedItemScores, fallback: 1.0);
      final chargeScores = <double>[
        _confidenceValue(updatedConfidence['tax_amount'], fallback: 1.0),
        _confidenceValue(updatedConfidence['service_charge'], fallback: 1.0),
        _confidenceValue(updatedConfidence['discount_amount'], fallback: 1.0),
        _confidenceValue(updatedConfidence['tip_amount'], fallback: 1.0),
        _confidenceValue(updatedConfidence['delivery_fee'], fallback: 1.0),
      ];
      final otherChargeScores = [
        for (final charge in (data['other_charges'] as List? ?? const []))
          if (charge is Map) _confidenceValue(charge['confidence_score']),
      ];

      final totalScore = _averageScores([
        subtotalScore,
        ...chargeScores,
      ], fallback: 1.0);
      final overallScore = _averageScores([
        ...updatedItemScores,
        ...chargeScores,
        ...otherChargeScores,
        totalScore,
      ], fallback: 1.0);

      updatedConfidence.addAll({
        'overall': overallScore,
        'subtotal': subtotalScore,
        'tax_amount': chargeScores[0],
        'service_charge': chargeScores[1],
        'discount_amount': chargeScores[2],
        'tip_amount': chargeScores[3],
        'delivery_fee': chargeScores[4],
        'total_amount': totalScore,
      });
      data['confidence_scores'] = updatedConfidence;
      final threshold = kReviewConfidenceThreshold;
      data['needs_review'] =
          updatedItemScores.any((score) => score < threshold) ||
          otherChargeScores.any((score) => score < threshold) ||
          chargeScores.any((score) => score < threshold) ||
          totalScore < threshold;
      data['warnings'] = data['needs_review'] == true
          ? List<String>.from(data['warnings'] ?? const [])
          : <String>[];
      _recomputeTotals();
    });
  }

  void _addItemFromDialog(String name, String qtyText, String priceText) {
    final nameValue = name.trim();
    if (nameValue.isEmpty) return;
    _itemControllers.add({
      'name': TextEditingController(text: nameValue),
      'qty': TextEditingController(text: qtyText),
      'price': TextEditingController(text: priceText),
    });
    _saveChanges();
  }

  void _updateItemFromDialog(
    int index,
    String name,
    String qtyText,
    String priceText,
  ) {
    if (index < 0 || index >= _itemControllers.length) return;
    final nameValue = name.trim();
    if (nameValue.isEmpty) return;
    final controllers = _itemControllers[index];
    controllers['name']!.text = nameValue;
    controllers['qty']!.text = qtyText;
    controllers['price']!.text = priceText;
    _saveChanges();
  }

  void _deleteItemFromDialog(int index) {
    if (index < 0 || index >= _itemControllers.length) return;
    final removed = _itemControllers.removeAt(index);
    // Keep receipt items aligned with the rows before re-saving.
    final items = _receiptData?['items'];
    if (items is List && index < items.length) items.removeAt(index);
    removed['name']?.dispose();
    removed['qty']?.dispose();
    removed['price']?.dispose();
    _saveChanges();
  }

  // ------------------------------------------------------ picking

  bool get _canOpenSettings =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void _showPickError(Object error) {
    if (!mounted) return;
    final access = scanAccessProblemOf(error);
    AppHaptics.error();
    if (access != null) {
      setState(() {
        _error = scanAccessContentFor(
          access,
          canOpenSettings: _canOpenSettings,
        );
      });
      return;
    }
    AppToast.show(
      context,
      message: 'bf_scan_err_unknown_msg'.tr(),
      type: AppToastType.error,
      haptic: false,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final isPremium = RevenueCatService.isUserActivePremium(userData);

      if (!isPremium) {
        final points = (userData?['points'] as num?)?.toInt() ?? 0;
        if (points < FeatureCosts.receiptScanPoints) {
          AnalyticsService.instance.receiptScan('no_points');
          await _showNoPointsDialog(FeatureCosts.receiptScanPoints);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error checking points: $e');
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bf_scan_err_points_check'.tr(),
        type: AppToastType.error,
      );
      return;
    }

    await _proceedWithImagePick(source);
  }

  Future<void> _proceedWithImagePick(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        await _cropImage(pickedFile.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      _showPickError(e);
    }
  }

  Future<void> _showNoPointsDialog(int requiredPoints) async {
    await NoPointsDialog.show(
      context,
      requiredPoints: requiredPoints,
      onWatchAd: _watchAdForPoint,
      onTypeItIn: _openManualEntry,
    );
  }

  Future<void> _watchAdForPoint() async {
    if (!RewardedAdHelper.isReady) {
      AppToast.show(
        context,
        message: 'fetching_an_ad_please_try_again_in_a_moment'.tr(),
        type: AppToastType.info,
      );
      try {
        await RewardedAdHelper.loadAd();
      } catch (e) {
        debugPrint('Ad failed to initialize: $e');
      }
      return;
    }

    await RewardedAdHelper.showAdAndReward(
      onRewardEarned: () {
        if (mounted) {
          AppToast.show(
            context,
            message: 'you_earned_1_point_you_can_now_use_the_scanner'.tr(),
            type: AppToastType.success,
          );
        }
      },
      onAdFailed: () {
        if (mounted) {
          AppToast.show(
            context,
            message: 'ads_are_currently_unavailable_please_try_again_later'
                .tr(),
            type: AppToastType.warning,
          );
        }
      },
    );
  }

  Future<void> _cropImage(String sourcePath) async {
    final p = context.palette;
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'adjust_receipt'.tr(),
          toolbarColor: p.inverseSurface,
          toolbarWidgetColor: p.onInverseSurface,
          activeControlsWidgetColor: p.accent,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'adjust_receipt'.tr(),
          aspectRatioLockEnabled: false,
        ),
      ],
    );

    if (croppedFile != null && mounted) {
      setState(() {
        _image = File(croppedFile.path);
        _receiptData = null;
      });
      await _analyzeImage();
    }
  }

  // ------------------------------------------------------ reading

  /// One user attempt: one request id. Retrying starts a new attempt.
  Future<void> _analyzeImage() async {
    final image = _image;
    if (image == null || _phase == _ScanPhase.reading) return;
    final attempt = ++_attempt;
    final requestId = const Uuid().v4();

    setState(() {
      _phase = _ScanPhase.reading;
      _error = null;
    });
    AppHaptics.light();

    final appSettings = context.read<AppSettingsProvider>();
    try {
      final data = await _receiptService.scanReceiptImage(
        image,
        localeCode: appSettings.locale.languageCode,
        currencyCode: appSettings.currencyCode,
        requestId: requestId,
      );
      if (!mounted || attempt != _attempt) return;

      setState(() {
        _receiptData = data;
        _receiptData!['currency_code'] ??= appSettings.currencyCode;
        final rawDate = DateTime.tryParse(data['date']?.toString() ?? '');
        if (rawDate != null && !rawDate.isAfter(DateTime.now())) {
          _selectedDate = rawDate;
        }
        _initializeControllers();
        _phase = _ScanPhase.review;
      });
      AppHaptics.success();
      AnalyticsService.instance.receiptScan('success');
    } catch (e) {
      debugPrint('Receipt scan failed: $e');
      if (!mounted || attempt != _attempt) return;
      final content = scanErrorContentForError(e);
      setState(() {
        _phase = _ScanPhase.idle;
        _error = content;
      });
      AppHaptics.error();
      final noCredits =
          e is ReceiptScanException &&
          e.failure == ReceiptScanFailure.noCredits;
      AnalyticsService.instance.receiptScan(noCredits ? 'no_points' : 'fail');
      if (noCredits) {
        await _showNoPointsDialog(FeatureCosts.receiptScanPoints);
      }
    }
  }

  void _cancelReading() {
    AppHaptics.light();
    setState(() {
      _attempt++;
      _phase = _ScanPhase.idle;
    });
  }

  Future<void> _onErrorAction(ScanErrorAction action) async {
    switch (action) {
      case ScanErrorAction.retakePhoto:
        await _pickImage(ImageSource.camera);
      case ScanErrorAction.choosePhoto:
        await _pickImage(ImageSource.gallery);
      case ScanErrorAction.typeItIn:
        _openManualEntry();
      case ScanErrorAction.tryAgain:
        if (_image == null) {
          await _pickImage(ImageSource.camera);
        } else {
          await _analyzeImage();
        }
      case ScanErrorAction.openSettings:
        try {
          final opened = await launchUrl(Uri.parse('app-settings:'));
          if (!opened) throw StateError('settings');
        } catch (_) {
          if (mounted) {
            AppToast.show(
              context,
              message: 'bf_scan_err_camera_msg'.tr(),
              type: AppToastType.info,
            );
          }
        }
      case ScanErrorAction.getCredits:
        await _showNoPointsDialog(FeatureCosts.receiptScanPoints);
    }
  }

  void _openManualEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualEntryScreen(
          participants: widget.participants,
          groupId: widget.groupId,
        ),
      ),
    );
  }

  // ------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget body;
    PreferredSizeWidget? appBar;
    switch (_phase) {
      case _ScanPhase.reading:
        body = ScanReadingView(
          key: const ValueKey('reading'),
          image: _image,
          onCancel: _cancelReading,
        );
      case _ScanPhase.saving:
        body = const ScanReadingView(
          key: ValueKey('saving'),
          titleKey: 'saving_for_later',
          subtitleKey: 'bf_scan_saving_hint',
          showPrivacyNote: false,
          onCancel: null,
        );
      case _ScanPhase.review:
        body = SafeArea(top: false, child: _buildResultState());
      case _ScanPhase.idle:
        appBar = ScanTopBar(
          title: 'scan_receipt'.tr(),
          trailing: [_buildHeaderTrailing(showDelete: true)],
        );
        body = ScanEmptyState(
          key: const ValueKey('idle'),
          image: _image,
          onSnapAndSave: _handleSnapAndSave,
          onAnalyze: _analyzeImage,
          onTakePhoto: () => _pickImage(ImageSource.camera),
          onChoosePhoto: () => _pickImage(ImageSource.gallery),
          onTypeItIn: _openManualEntry,
          errorCard: _error == null
              ? null
              : ScanErrorCard(content: _error!, onAction: _onErrorAction),
        );
    }

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: appBar,
      body: AnimatedSwitcher(
        duration: AppMotion.durationFor(context, AppMotion.slow),
        child: body,
      ),
    );
  }

  Widget _buildHeaderTrailing({required bool showDelete}) {
    final canDeleteDraft = showDelete && widget.billId != null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final delete = canDeleteDraft
        ? ScanRoundButton(
            icon: Icons.delete_outline_rounded,
            label: 'delete_saved_draft'.tr(),
            color: context.palette.error,
            onPressed: _busy ? null : _confirmDeleteSavedDraft,
          )
        : null;
    if (uid == null) return delete ?? const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final Widget? badge = !snapshot.hasData
            ? null
            : RevenueCatService.isUserActivePremium(userData)
            ? _buildProBadge()
            : _buildPointsBadge((userData?['points'] as num?)?.toInt() ?? 0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (delete != null) delete,
            if (delete != null && badge != null) const SizedBox(width: 8),
            ?badge,
          ],
        );
      },
    );
  }

  Widget _buildProBadge() {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.premium,
        borderRadius: AppRadii.chipRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, color: p.onPremium, size: 14),
          const SizedBox(width: 4),
          Text(
            'pro'.tr(),
            style: AppTypography.labelSmall.copyWith(
              color: p.onPremium,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsBadge(int points) {
    final p = context.palette;
    return Semantics(
      label: '$points',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: p.oweSoft,
          borderRadius: AppRadii.chipRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stars_rounded, color: p.oweInk, size: 14),
            const SizedBox(width: 4),
            Text(
              '$points',
              style: AppTypography.amountSmall.copyWith(
                fontSize: 13,
                color: p.oweInk,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultState() {
    final canDeleteDraft = widget.billId != null;
    return ReceiptResultView(
      receiptData: _receiptData!,
      itemControllers: _itemControllers,
      currencyCode: _currency,
      restaurantController: _restaurantController,
      taxController: _taxController,
      serviceController: _serviceController,
      discountController: _discountController,
      tipController: _tipController,
      deliveryController: _deliveryController,
      onSave: _saveChanges,
      onAddItem: _addItemFromDialog,
      onUpdateItem: _updateItemFromDialog,
      onDeleteItem: _deleteItemFromDialog,
      selectedDate: _selectedDate,
      onDateChanged: (date) => setState(() => _selectedDate = date),
      image: _image,
      participants: widget.participants,
      headerTrailing: [
        if (canDeleteDraft)
          ScanRoundButton(
            icon: Icons.delete_outline_rounded,
            label: 'delete_saved_draft'.tr(),
            color: context.palette.error,
            onPressed: _busy ? null : _confirmDeleteSavedDraft,
          ),
      ],
      bottom: _buildBottomAction(),
    );
  }

  Widget _buildBottomAction() {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const ValueKey('scan-review-cta'),
          onPressed: () {
            _saveChanges();
            final items = _receiptData?['items'];
            if (items is! List || items.isEmpty) {
              AppToast.show(
                context,
                message: 'add_at_least_one_item'.tr(),
                type: AppToastType.error,
              );
              return;
            }
            AppHaptics.selection();
            _showAssignmentMethodSheet();
          },
          child: Text('bf_scan_review_cta'.tr()),
        ),
      ),
    );
  }

  void _showAssignmentMethodSheet() {
    // Assignment (by hand or by voice) is chosen on the split screen.
    _goToManualAssignment();
  }

  void _goToManualAssignment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => SplitBillScreen(
          receiptData: _receiptData!,
          preSelectedContacts: null,
          initialParticipants: widget.participants,
          groupId: widget.groupId,
          resumedBillId: widget.billId,
          cleanupImagePath: widget.initialLocalImagePath,
        ),
      ),
    );
  }
}
