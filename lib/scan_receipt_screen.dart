import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'services/receipt_service.dart';
import 'split_bill_screen.dart';
import 'package:lottie/lottie.dart';
import 'widgets/receipt_result_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'helpers/rewarded_ad_helper.dart';
import 'providers/app_settings_provider.dart';
import 'widgets/custom_app_header.dart';
import 'widgets/voice_command_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/scan_receipt/widgets/no_points_dialog.dart';
import 'screens/scan_receipt/widgets/image_source_sheet.dart';
import 'screens/scan_receipt/widgets/assignment_method_sheet.dart';
import 'screens/scan_receipt/widgets/participants_reference_list.dart';
import 'screens/scan_receipt/widgets/scan_empty_state.dart';

class ScanReceiptScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? participants;
  final String? billId; // For resuming
  final String? initialLocalImagePath; // For resuming

  const ScanReceiptScreen({
    super.key,
    this.participants,
    this.billId,
    this.initialLocalImagePath,
  });

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen>
    with TickerProviderStateMixin {
  final ReceiptService _receiptService = ReceiptService();
  final ImagePicker _picker = ImagePicker();

  File? _image;
  bool _isLoading = false;
  Map<String, dynamic>? _receiptData;
  String _loadingMessage = "Analyzing Receipt...";
  late AnimationController _loadingTextController;

  // Editing State
  bool _isEditing = false;
  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _serviceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _tipController = TextEditingController();
  final TextEditingController _deliveryController = TextEditingController();

  List<Map<String, TextEditingController>> _itemControllers = [];

  @override
  void initState() {
    super.initState();
    _loadingTextController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    RewardedAdHelper.warmUpIfEligible();

    // Resume if data provided
    if (widget.initialLocalImagePath != null) {
      _loadSavedImage();
    }
  }

  Future<void> _loadSavedImage() async {
    final file = File(widget.initialLocalImagePath!);
    if (await file.exists()) {
      setState(() {
        _image = file;
      });
      // Optionally auto-analyze or just show ready state
      // _analyzeImage(); // Let user tap to analyze
    }
  }

  @override
  void dispose() {
    _loadingTextController.dispose();
    _restaurantController.dispose();
    _totalController.dispose();
    _taxController.dispose();
    _serviceController.dispose();
    _discountController.dispose();
    _tipController.dispose();
    _deliveryController.dispose();
    for (var controllers in _itemControllers) {
      controllers['name']?.dispose();
      controllers['qty']?.dispose();
      controllers['price']?.dispose();
    }
    super.dispose();
  }

  void _disposeItemControllers() {
    for (var controllers in _itemControllers) {
      controllers['name']?.dispose();
      controllers['qty']?.dispose();
      controllers['price']?.dispose();
    }
    _itemControllers = [];
  }

  // ... (controllers init and update logic keep same)

  // --- SNAP & SAVE HANDLER ---
  Future<void> _handleSnapAndSave() async {
    if (_image == null) {
      if (_isLoading) return;
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
        debugPrint("Error picking image: $e");
      }
    } else {
      await _saveForLater();
    }
  }

  // --- SAVE FOR LATER LOGIC ---
  Future<void> _saveForLater() async {
    if (_image == null) return;

    setState(() => _isLoading = true);
    _loadingMessage = "Saving for later...";

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Save Image Locally
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await _image!.copy('${directory.path}/$fileName');

      // Prepare participants_uids for querying
      List<String> participantUids = [user.uid]; // Host is always a participant
      if (widget.participants != null) {
        for (var p in widget.participants!) {
          if (p.containsKey('uid') && p['uid'] != null) {
            participantUids.add(p['uid']);
          } else if (p.containsKey('id') && p['id'] != null) {
            participantUids.add(p['id']);
          }
        }
      }

      // 2. Create Bill Document
      final billData = {
        'hostId': user.uid,
        'hostName': user.displayName ?? "Host",
        'participants': widget.participants ?? [],
        'participants_uids': participantUids, // Saved for querying
        'date': Timestamp.now(),
        'status': 'UNATTEMPTED',
        'localImagePath': savedImage.path,
        'storeName': "Unattempted Receipt", // Placeholder
        'items': [],
        'charges': {},
      };

      if (widget.billId != null) {
        // Update existing
        await FirebaseFirestore.instance
            .collection('bills')
            .doc(widget.billId)
            .update(billData);
      } else {
        // Create new
        await FirebaseFirestore.instance.collection('bills').add(billData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved for later!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back to Home
        Navigator.pop(context); // Pop Setup Screen if applicable
      }
    } catch (e) {
      debugPrint("Error saving for later: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Keep existing methods: _initializeControllers, _updateTotal, _saveChanges, _pickImage, etc.)
  // I will use multi_replace for specific insertions to avoid overwriting too much,
  // but since I'm rewriting the top part, I'll stick to replacing the needed chunks.

  void _initializeControllers() {
    if (_receiptData == null) return;
    _disposeItemControllers();

    _restaurantController.text = _receiptData!['restaurant_name'] ?? "";
    _totalController.text = (_receiptData!['total_amount'] ?? 0)
        .toStringAsFixed(2);
    _taxController.text = (_receiptData!['tax_amount'] ?? 0).toString();
    _serviceController.text = (_receiptData!['service_charge'] ?? 0).toString();
    _discountController.text = (_receiptData!['discount_amount'] ?? 0)
        .toString();
    _tipController.text = (_receiptData!['tip_amount'] ?? 0).toString();
    _deliveryController.text = (_receiptData!['delivery_fee'] ?? 0).toString();

    void onUpdate() => _updateTotal();

    _taxController.addListener(onUpdate);
    _serviceController.addListener(onUpdate);
    _discountController.addListener(onUpdate);
    _tipController.addListener(onUpdate);
    _deliveryController.addListener(onUpdate);

    _itemControllers = (_receiptData!['items'] as List).map((item) {
      final nameCtrl = TextEditingController(text: item['name'] ?? "");
      final qtyCtrl = TextEditingController(
        text: (item['qty'] ?? 1).toString(),
      );
      final priceCtrl = TextEditingController(
        text: (item['price'] as num).toDouble().toString(),
      );

      nameCtrl.addListener(onUpdate);
      qtyCtrl.addListener(onUpdate);
      priceCtrl.addListener(onUpdate);

      return {'name': nameCtrl, 'qty': qtyCtrl, 'price': priceCtrl};
    }).toList();

    _updateTotal(); // Initial calculation
  }

  void _updateTotal() {
    double subtotal = 0;
    for (var controllers in _itemControllers) {
      double qty = double.tryParse(controllers['qty']!.text) ?? 0;
      double price = double.tryParse(controllers['price']!.text) ?? 0;
      subtotal += qty * price;
    }

    double tax = double.tryParse(_taxController.text) ?? 0;
    double service = double.tryParse(_serviceController.text) ?? 0;
    double discount = double.tryParse(_discountController.text) ?? 0;
    double tip = double.tryParse(_tipController.text) ?? 0;
    double delivery = double.tryParse(_deliveryController.text) ?? 0;
    double otherChargesTotal =
        (_receiptData?['other_charges_total'] as num?)?.toDouble() ?? 0.0;

    double finalTotal =
        subtotal + tax + service + tip + delivery + otherChargesTotal - discount;

    setState(() {
      _totalController.text = finalTotal.toStringAsFixed(2);
      _receiptData!['total_amount'] = finalTotal;
      _receiptData!['subtotal'] = subtotal;
      _receiptData!['tax_amount'] = tax;
      _receiptData!['service_charge'] = service;
      _receiptData!['discount_amount'] = discount;
      _receiptData!['tip_amount'] = tip;
      _receiptData!['delivery_fee'] = delivery;
    });
  }

  void _saveChanges() {
    _updateTotal(); // Ensure everything is up to date
    setState(() {
      _receiptData!['restaurant_name'] = _restaurantController.text;

      final List<Map<String, dynamic>> updatedItems = [];
      for (var controllers in _itemControllers) {
        final name = controllers['name']!.text.trim();
        if (name.isEmpty) continue;
        updatedItems.add({
          'name': name,
          'qty': int.tryParse(controllers['qty']!.text) ?? 1,
          'price': double.tryParse(controllers['price']!.text) ?? 0.0,
        });
      }
      _receiptData!['items'] = updatedItems;
      _isEditing = false;
    });
    HapticFeedback.mediumImpact();
  }

  void _addEmptyItem() {
    setState(() {
      _itemControllers.add({
        'name': TextEditingController(),
        'qty': TextEditingController(text: '1'),
        'price': TextEditingController(text: '0'),
      });
    });
    _updateTotal();
  }

  void _removeItem(int index) {
    if (index < 0 || index >= _itemControllers.length) return;

    final removed = _itemControllers.removeAt(index);
    removed['name']?.dispose();
    removed['qty']?.dispose();
    removed['price']?.dispose();

    setState(() {});
    _updateTotal();
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
      final isPremium = userData?['isPremium'] ?? false;

      if (isPremium) {
        await _proceedWithImagePick(source);
        return;
      }

      final points = userData?['points'] ?? 0;
      if (points <= 0) {
        await _showNoPointsDialog();
        return;
      }

      await _proceedWithImagePick(source);
    } catch (e) {
      debugPrint("Error checking points: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _proceedWithImagePick(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        _cropImage(pickedFile.path);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _showNoPointsDialog() async {
    await NoPointsDialog.show(context, onWatchAd: _watchAdForPoint);
  }

  Future<void> _watchAdForPoint() async {
    if (!RewardedAdHelper.isReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fetching an ad... Please try again in a moment."),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.blueAccent,
        ),
      );
      try {
        await RewardedAdHelper.loadAd();
      } catch (e) {
        debugPrint("Ad failed to initialize: $e");
      }
      return;
    }

    await RewardedAdHelper.showAdAndReward(
      onRewardEarned: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "🎉 You earned 1 point! You can now use the scanner.",
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onAdFailed: () {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Notice"),
              content: const Text(
                "Ads are currently unavailable. Please try again later.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Got it"),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Future<void> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Adjust Receipt',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Adjust Receipt', aspectRatioLockEnabled: false),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _image = File(croppedFile.path);
        _receiptData = null;
      });
      _analyzeImage();
    }
  }

  Future<void> _deductPointAfterSuccessfulScan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      final isPremium = userData?['isPremium'] ?? false;

      if (!isPremium) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'points': FieldValue.increment(-1)});
      }
    } catch (e) {
      debugPrint("Error deducting point: $e");
    }
  }

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = "Scanning receipt with AI...";
    });
    HapticFeedback.mediumImpact();

    try {
      final appSettings = context.read<AppSettingsProvider>();
      final data = await _receiptService.scanReceiptImage(
        _image!,
        localeCode: appSettings.locale.languageCode,
        currencyCode: appSettings.currencyCode,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _receiptData = data;
          _receiptData!['currency_code'] ??= appSettings.currencyCode;
          _initializeControllers();
        });

        HapticFeedback.mediumImpact();
        await _deductPointAfterSuccessfulScan();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Scan failed: ${e.toString().replaceFirst('Exception: ', '')}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppHeader(
        title: _receiptData == null ? "Scan Receipt" : "Scan Completed",
        trailing: _buildHeaderTrailing(),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _isLoading
            ? _buildLoadingState()
            : (_receiptData == null ? _buildEmptyState() : _buildResultState()),
      ),
      floatingActionButton: null,
    );
  }

  Future<void> _showVoiceOverlay() async {
    if (_receiptData == null) return;

    List<Map<String, dynamic>> effectiveParticipants =
        List<Map<String, dynamic>>.from(widget.participants ?? const []);

    if (effectiveParticipants.isEmpty) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        effectiveParticipants = [
          {
            'id': currentUser.uid,
            'name': currentUser.displayName ?? currentUser.email ?? 'Me',
          },
        ];
      }
    }

    final assignments = await showDialog<Map<String, List<String>>>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => VoiceCommandOverlay(
        receiptData: _receiptData!,
        participants: effectiveParticipants,
      ),
    );

    if (assignments != null && assignments.isNotEmpty) {
      if (mounted) {
        // Navigate to Split Screen with assignments
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SplitBillScreen(
              receiptData: _receiptData!,
              initialParticipants: widget.participants,
              initialAssignments: assignments,
              resumedBillId: widget.billId,
              cleanupImagePath: widget.initialLocalImagePath,
            ),
          ),
        );
      }
    }
  }

  Widget _buildHeaderTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(width: 48);

            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            final isPremium = userData?['isPremium'] ?? false;

            if (isPremium) {
              return _buildProBadge();
            }

            final points = userData?['points'] ?? 0;
            return _buildPointsBadge(points);
          },
        ),
        if (_receiptData != null)
          IconButton(
            icon: Icon(
              _isEditing ? Icons.save_rounded : Icons.edit_rounded,
              color: const Color(0xFF00B365),
            ),
            onPressed: () {
              if (_isEditing) {
                _saveChanges();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
      ],
    );
  }

  Widget _buildProBadge() {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Text(
            "PRO",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsBadge(int points) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            '$points',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ScanEmptyState(
      image: _image,
      onSnapAndSave: _handleSnapAndSave,
      onAnalyze: _analyzeImage,
      onPickImage: () => _showImageSourceActionSheet(context),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 250,
            child: Lottie.asset('assets/animations/scan.json'),
          ),
          const SizedBox(height: 40),
          FadeTransition(
            opacity: _loadingTextController,
            child: Text(
              _loadingMessage,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Our backend is extracting items, quantities, and charges securely.",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 50),
          Lottie.asset('assets/animations/loading.json', height: 60),
        ],
      ),
    );
  }

  Widget _buildResultState() {
    return Column(
      children: [
        ParticipantsReferenceList(participants: widget.participants),
        Expanded(
          child: ReceiptResultView(
            receiptData: _receiptData!,
            isEditing: _isEditing,
            itemControllers: _itemControllers,
            currencyCode: _receiptData!['currency_code'] ?? 'USD',
            restaurantController: _restaurantController,
            totalController: _totalController,
            taxController: _taxController,
            serviceController: _serviceController,
            discountController: _discountController,
            tipController: _tipController,
            deliveryController: _deliveryController,
            onSave: _saveChanges,
            onAddItem: _addEmptyItem,
            onDeleteItem: _removeItem,
            onCancel: () => setState(() => _isEditing = false),
          ),
        ),
        _buildBottomAction(),
      ],
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ImageSourceSheet(onPickImage: _pickImage),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (_isEditing) {
                _saveChanges();
              } else {
                _showAssignmentMethodSheet();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B365),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: Text(
              _isEditing ? 'scan_save_changes'.tr() : 'scan_next_step'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignmentMethodSheet() {
    // If no contacts were pre-selected, go straight to manual (legacy flow)
    if (widget.participants == null || widget.participants!.isEmpty) {
      _goToManualAssignment();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AssignmentMethodSheet(
        onVoiceCommand: _showVoiceOverlay,
        onManualAssignment: _goToManualAssignment,
      ),
    );
  }

  void _goToManualAssignment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => SplitBillScreen(
          receiptData: _receiptData!,
          preSelectedContacts: null,
          initialParticipants: widget.participants,
          resumedBillId: widget.billId,
          cleanupImagePath: widget.initialLocalImagePath,
        ),
      ),
    );
  }
}
