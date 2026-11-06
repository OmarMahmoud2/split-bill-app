import 'package:split_bill_app/services/analytics_service.dart';
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/screens/split_bill/bill_roulette_screen.dart';
import 'package:split_bill_app/screens/split_bill/bill_share_screen.dart';
import 'package:split_bill_app/screens/split_bill/split_method_screen.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assign_widgets.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_sheets.dart';
import 'package:split_bill_app/services/notification_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/offline_write.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_breakdown_card.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Friendly key + args for the first issue of a computation. Pure.
(String, Map<String, String>)? summaryIssueCopy(
  BillComputation c, {
  List<String> itemNames = const [],
}) {
  if (c.issues.isEmpty) return null;
  String money(int m) => formatMoneyMinor(m, c.draft.currency);
  String item(int i) => i < itemNames.length ? itemNames[i] : '#${i + 1}';
  return switch (c.issues.first) {
    NoParticipantsIssue() => ('bf_summary_issue_no_people', const {}),
    UnassignedItemIssue(:final index) => (
      'bf_summary_issue_unassigned',
      {'item': item(index)},
    ),
    OverAssignedItemIssue(:final index) => (
      'bf_summary_issue_unassigned',
      {'item': item(index)},
    ),
    ExactMismatchIssue(:final remainingMinor) => (
      'bf_summary_issue_split',
      {'amount': money(remainingMinor.abs())},
    ),
    PercentMismatchIssue() => ('bf_summary_issue_percent', const {}),
    NoSharesIssue() => ('bf_split_shares_none', const {}),
    DiscountTooLargeIssue() => ('bf_split_discount_too_large', const {}),
    OverrideExceedsTotalIssue(:final totalMinor) => (
      'bf_summary_issue_override',
      {'amount': money(totalMinor)},
    ),
    OverrideMismatchIssue(:final totalMinor) => (
      'bf_summary_issue_override',
      {'amount': money(totalMinor)},
    ),
  };
}

/// Summary, "every cent accounted for" (Split.dc.html, second board):
/// the total, each person's share with an expandable breakdown, charge
/// editing, bill roulette, and "Save and share".
class BillSummaryConfirmScreen extends StatefulWidget {
  final Map<String, dynamic> receiptData;
  final List<Map<String, dynamic>> participants;
  final Map<int, List<String>> itemAssignments;
  final Map<int, Map<String, int>> quantityAssignments;
  final double taxAmount;
  final double serviceChargeAmount;
  final double tipAmount;
  final double discountAmount;
  final double deliveryFeeAmount;
  final String? oldBillIdToDelete;
  final String? oldImageToDelete;

  /// A whole-bill split (equal / exact / percent / shares) chosen on the
  /// split method screen; null means "by item" from the assignments.
  final BillDraft? methodDraft;

  /// Ledger / group the bill belongs to (data contract `groupId`).
  final String? groupId;

  /// Test seam: when set, the screen does not touch Firebase or ads and
  /// calls this instead of saving.
  @visibleForTesting
  final Future<String> Function(Map<String, dynamic> billData)? debugSave;

  const BillSummaryConfirmScreen({
    this.methodDraft,
    this.groupId,
    super.key,
    required this.receiptData,
    required this.participants,
    required this.itemAssignments,
    required this.quantityAssignments,
    required this.taxAmount,
    required this.serviceChargeAmount,
    required this.tipAmount,
    this.discountAmount = 0.0,
    this.deliveryFeeAmount = 0.0,
    this.oldBillIdToDelete,
    this.oldImageToDelete,
    this.debugSave,
  });

  @override
  State<BillSummaryConfirmScreen> createState() =>
      _BillSummaryConfirmScreenState();
}

class _BillSummaryConfirmScreenState extends State<BillSummaryConfirmScreen> {
  late BillDraft _draft;
  bool _isCreating = false;
  String? _expandedId;
  late final NotificationService _notificationService = NotificationService();

  bool get _testing => widget.debugSave != null;

  String get _storeName =>
      (widget.receiptData['restaurant_name'] ??
              widget.receiptData['storeName'] ??
              'bf_summary_default_store'.tr())
          .toString();

  String _currencyCode() {
    final fromReceipt =
        widget.receiptData['currency_code'] ??
        widget.receiptData['currencyCode'] ??
        widget.receiptData['currency'];
    if (fromReceipt != null && fromReceipt.toString().trim().isNotEmpty) {
      return fromReceipt.toString();
    }
    try {
      return context.read<AppSettingsProvider>().currencyCode;
    } catch (_) {
      return 'USD';
    }
  }

  List<String> get _ids => [
    for (final p in widget.participants) (p['id'] ?? '').toString(),
  ];

  List<String> get _itemNames => [
    for (final i in (widget.receiptData['items'] as List?) ?? const [])
      if (i is Map) (i['name'] ?? '').toString(),
  ];

  @override
  void initState() {
    super.initState();
    _draft =
        widget.methodDraft ??
        draftFromReceipt(
          receiptData: widget.receiptData,
          participantIds: _ids,
          currency: _currencyCode(),
          itemAssignments: widget.itemAssignments,
          quantityAssignments: widget.quantityAssignments,
          tax: widget.taxAmount,
          service: widget.serviceChargeAmount,
          tip: widget.tipAmount,
          discount: widget.discountAmount,
          delivery: widget.deliveryFeeAmount,
        );
  }

  Map<String, dynamic> _participant(String id) {
    for (final p in widget.participants) {
      if (p['id']?.toString() == id) return Map<String, dynamic>.from(p);
    }
    return {'id': id};
  }

  String _displayName(Map<String, dynamic> p) {
    final name = (p['name'] ?? '?').toString();
    if (p['isHost'] == true) {
      return 'bf_summary_you_suffix'.tr(namedArgs: {'name': name});
    }
    return name;
  }

  // --- Editing ---------------------------------------------------------

  Future<void> _editCharges() async {
    final result = await showModalBottomSheet<BillDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetRadius),
      builder: (_) => _ChargesSheet(draft: _draft),
    );
    if (result == null || !mounted) return;
    AppHaptics.success();
    setState(() => _draft = result.copyWith(overrides: const {}));
  }

  Future<void> _editSplit() async {
    final result = await SplitMethodScreen.open(
      context,
      draft: _draft,
      participants: widget.participants,
    );
    if (result == null || !mounted) return;
    if (result.method == SplitMethod.items &&
        result.itemAssignments.isEmpty &&
        result.quantityAssignments.isEmpty) {
      // Nothing assigned yet: go back to the "who had what" screen.
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _draft = result.copyWith(overrides: const {}));
  }

  Future<void> _editShare(String id) async {
    final p = context.palette;
    final current = computeBill(_draft).shareOf(id);
    final decimals = currencyDecimals(_draft.currency);
    final controller = TextEditingController(
      text: fromMinorUnits(current, _draft.currency).toStringAsFixed(decimals),
    );
    final name = _displayName(_participant(id));
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: AppRadii.cardShape(p.hairline),
        title: Text(
          'bf_summary_edit_share_title'.tr(namedArgs: {'name': name}),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'bf_summary_edit_share_body'.tr(),
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(
                decimal: decimals > 0,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                prefixText: '${_draft.currency} ',
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.rowRadius,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('common_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              minorFromAny(controller.text, _draft.currency),
            ),
            child: Text('bf_summary_edit_share_save'.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    final next = _draft.copyWith(
      overrides: {..._draft.overrides, id: value},
      clearRoulette: true,
    );
    final c = computeBill(next);
    if (!c.isValid) {
      AppHaptics.error();
      final copy = summaryIssueCopy(c, itemNames: _itemNames);
      AppToast.show(
        context,
        message: copy == null ? '' : copy.$1.tr(namedArgs: copy.$2),
        type: AppToastType.error,
      );
      return;
    }
    AppHaptics.selection();
    setState(() => _draft = next);
    AppToast.show(
      context,
      message: 'bf_summary_rebalanced'.tr(),
      type: AppToastType.info,
    );
  }

  void _resetShares() {
    AppHaptics.selection();
    setState(
      () => _draft = _draft.copyWith(overrides: const {}, clearRoulette: true),
    );
  }

  Future<void> _roulette() async {
    if (widget.participants.length < 2) {
      AppToast.show(
        context,
        message: 'need_at_least_two_people_for_bill_roulette'.tr(),
        type: AppToastType.warning,
      );
      return;
    }
    final winner = await BillRouletteScreen.open(
      context,
      participants: widget.participants,
      totalMinor: _draft.grandTotalMinor,
      currency: _draft.currency,
    );
    if (winner == null || !mounted) return;
    setState(
      () => _draft = _draft.copyWith(
        overrides: const {},
        rouletteWinnerId: winner,
      ),
    );
    AppToast.show(
      context,
      message: 'bf_summary_roulette_applied'.tr(
        namedArgs: {'name': (_participant(winner)['name'] ?? '').toString()},
      ),
      type: AppToastType.success,
    );
  }

  // --- Saving ----------------------------------------------------------

  Map<String, dynamic> _buildBillData(
    BillComputation c,
    String hostUid,
    String? hostName,
  ) {
    final fields = buildBillFields(
      computation: c,
      participants: [
        for (final p in widget.participants) BillParticipantInfo.fromMap(p),
      ],
      hostUid: hostUid,
      storeName: _storeName,
      groupId: widget.groupId,
    );
    final rawDate = widget.receiptData['date'];
    final parsedDate = rawDate == null
        ? null
        : DateTime.tryParse(rawDate.toString());
    return {
      ...fields,
      'hostId': hostUid,
      'hostName': hostName,
      'date': parsedDate != null
          ? Timestamp.fromDate(parsedDate)
          : _testing
          ? Timestamp.now()
          : FieldValue.serverTimestamp(),
      'history': appendHistory(null, [
        BillHistoryEntry(
          by: hostUid,
          byName: hostName,
          at: DateTime.now(),
          change: 'created',
        ),
      ]),
    };
  }

  Future<Map<String, String>?> _hostPaymentMethods(String uid) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await ref.get().timeout(const Duration(seconds: 4));
      } catch (_) {
        // Offline or slow: the cached copy is good enough here.
        doc = await ref.get(const GetOptions(source: Source.cache));
      }
      final data = doc.data();
      if (data == null) return null;
      final custom = data['customPaymentMethods'];
      if (custom is List && custom.isNotEmpty) {
        final map = <String, String>{};
        for (final m in custom) {
          if (m is Map) {
            final name = (m['name'] ?? '').toString();
            final value = (m['value'] ?? '').toString();
            if (name.isNotEmpty && value.isNotEmpty) map[name] = value;
          }
        }
        return map.isEmpty ? null : map;
      }
      final old = data['paymentMethods'];
      if (old is Map && old.isNotEmpty) {
        return old.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('payment methods: $e');
    }
    return null;
  }

  Future<void> _save() async {
    final c = computeBill(_draft);
    if (!c.isValid) {
      AppHaptics.error();
      final copy = summaryIssueCopy(c, itemNames: _itemNames)!;
      AppToast.show(
        context,
        message: copy.$1.tr(namedArgs: copy.$2),
        type: AppToastType.error,
      );
      return;
    }
    if (_isCreating) return;
    setState(() => _isCreating = true);
    AppHaptics.light();

    String billId;
    Map<String, dynamic> billData;
    var queued = false;
    try {
      if (_testing) {
        billData = _buildBillData(c, 'host', 'Host');
        billId = await widget.debugSave!(billData);
      } else {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw StateError('signed out');
        billData = _buildBillData(c, user.uid, user.displayName);
        final methods = await _hostPaymentMethods(user.uid);
        if (methods != null) billData['paymentMethods'] = methods;
        // `.doc()` + `set()` instead of `.add()`: the id is known up front
        // and, offline, the write queues on the device instead of hanging.
        final ref = FirebaseFirestore.instance.collection('bills').doc();
        billId = ref.id;
        final outcome = await commitOrQueue(
          ref.set(billData),
          onLateError: (e) {
            if (kDebugMode) debugPrint('queued bill write failed: $e');
            if (!mounted) return;
            AppToast.show(
              context,
              message: 'bf_summary_save_failed'.tr(),
              type: AppToastType.error,
            );
          },
        );
        queued = outcome == WriteOutcome.queued;
        unawaited(_cleanupResumed());
        _notifyAppUsers(c, billId, user.uid);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('save bill: $e');
      if (!mounted) return;
      setState(() => _isCreating = false);
      AppHaptics.error();
      AppToast.show(
        context,
        message: 'bf_summary_save_failed'.tr(),
        type: AppToastType.error,
        actionLabel: 'feedback_try_again'.tr(),
        onAction: _save,
      );
      return;
    }
    final rawItems = widget.receiptData['items'];
    AnalyticsService.instance.billCreated(
      source: widget.receiptData['entryMode'] == 'manual' ? 'manual' : 'scan',
      items: rawItems is List ? rawItems.length : 0,
      people: widget.participants.length,
      splitMethod: billData['splitMethod']?.toString() ?? 'items',
    );
    if (!mounted) return;
    // 2.0 has no interstitial ads: saving goes straight to the success screen.
    _showSuccess(billId, billData);
    if (queued) {
      AppToast.show(
        context,
        message: 'bf_summary_saved_offline'.tr(),
        type: AppToastType.info,
      );
    }
  }

  Future<void> _cleanupResumed() async {
    if (widget.oldBillIdToDelete != null) {
      try {
        await FirebaseFirestore.instance
            .collection('bills')
            .doc(widget.oldBillIdToDelete)
            .delete();
      } catch (e) {
        if (kDebugMode) debugPrint('delete resumed bill: $e');
      }
    }
    if (widget.oldImageToDelete != null) {
      try {
        final file = File(widget.oldImageToDelete!);
        if (await file.exists()) await file.delete();
      } catch (e) {
        if (kDebugMode) debugPrint('delete resumed image: $e');
      }
    }
  }

  void _notifyAppUsers(BillComputation c, String billId, String hostUid) {
    for (final p in widget.participants) {
      final id = (p['id'] ?? '').toString();
      if (p['isGuest'] == true || id == hostUid || id.isEmpty) continue;
      final amount = formatMoneyMinor(c.shareOf(id), _draft.currency);
      _notificationService
          .sendNotification(
            targetUid: id,
            title: 'split_bill_notification_title'.tr(
              namedArgs: {'store': _storeName},
            ),
            body: 'split_bill_notification_body'.tr(
              namedArgs: {'amount': amount},
            ),
            historyTitleKey: 'split_bill_notification_title',
            historyBodyKey: 'split_bill_notification_body',
            historyTitleArgs: {'store': _storeName},
            historyBodyArgs: {'amount': amount},
            data: {'type': 'new_bill', 'uid': id, 'billId': billId},
          )
          .then<void>(
            (_) {},
            onError: (Object e) {
              if (kDebugMode) debugPrint('notify $id: $e');
            },
          );
    }
  }

  List<ShareTarget> _shareTargets(Map<String, dynamic> billData) {
    final hostId = billData['hostId']?.toString();
    final reader = BillReader(billData);
    return [
      for (final p in reader.participants)
        ShareTarget(
          id: (p['id'] ?? '').toString(),
          name: (p['name'] ?? '').toString(),
          shareMinor: reader.shareMinorOf(p),
          photoUrl: p['photoUrl']?.toString(),
          phoneNumber: p['phoneNumber']?.toString(),
          isHost: p['id']?.toString() == hostId,
          isAppUser: p['isGuest'] != true,
        ),
    ];
  }

  void _showSuccess(String billId, Map<String, dynamic> billData) {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final targets = _shareTargets(billData);
    final hasOthers = targets.any((t) => !t.isHost);
    navigator.pushAndRemoveUntil(
      PageRouteBuilder<void>(
        transitionDuration: AppMotion.durationFor(context, AppMotion.slow),
        reverseTransitionDuration: AppMotion.durationFor(
          context,
          AppMotion.medium,
        ),
        pageBuilder: (ctx, _, _) => SuccessScreen(
          title: 'bf_share_title'.tr(),
          message: 'bf_summary_success_message'.tr(
            namedArgs: {'store': _storeName},
          ),
          amountMinor: _draft.grandTotalMinor,
          currency: _draft.currency,
          primaryLabel: hasOthers
              ? 'bf_summary_send_links'.tr()
              : 'bf_share_done'.tr(),
          onPrimary: () {
            if (!hasOthers) {
              Navigator.of(ctx).pop();
              return;
            }
            Navigator.of(ctx).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => BillShareScreen(
                  billId: billId,
                  storeName: _storeName,
                  currency: _draft.currency,
                  targets: targets,
                ),
              ),
            );
          },
          secondaryLabel: hasOthers ? 'bf_share_done'.tr() : null,
          onSecondary: hasOthers ? () => Navigator.of(ctx).pop() : null,
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
      (route) => route.isFirst,
    );
  }

  // --- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = computeBill(_draft);
    final issue = summaryIssueCopy(c, itemNames: _itemNames);
    final adjusted =
        _draft.overrides.isNotEmpty || _draft.rouletteWinnerId != null;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'bf_split_back'.tr(),
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: p.surface,
                      side: BorderSide(color: p.hairline),
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_rounded, color: p.textPrimary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'bf_summary_title'.tr(),
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('summary_edit_charges'),
                    onPressed: _editCharges,
                    style: TextButton.styleFrom(
                      foregroundColor: p.accent,
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(
                      'bf_summary_edit'.tr(),
                      style: AppTypography.labelLarge.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 16),
                children: [
                  Text(
                    'bf_summary_paid_by_you'.tr(
                      namedArgs: {'store': _storeName},
                    ),
                    style: AppTypography.bodyMedium.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                  MoneyText(
                    minor: c.grandTotalMinor,
                    currency: _draft.currency,
                    size: MoneySize.hero,
                    tone: MoneyTone.neutral,
                    animate: true,
                    animateFromZero: false,
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(height: 4),
                  _ChargesLine(draft: _draft),
                  if (issue != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        key: const ValueKey('summary_issue'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: p.oweSoft,
                          borderRadius: AppRadii.rowRadius,
                        ),
                        child: Text(
                          issue.$1.tr(namedArgs: issue.$2),
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: p.oweInk,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: AppRadii.cardRadius,
                      border: Border.all(color: p.hairline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < _ids.length; i++)
                          StaggeredEntrance(
                            index: i,
                            child: _PersonRow(
                              key: ValueKey('summary_person_${_ids[i]}'),
                              participant: _participant(_ids[i]),
                              name: _displayName(_participant(_ids[i])),
                              breakdown:
                                  c.people[_ids[i]] ??
                                  PersonBreakdown(id: _ids[i], lines: const []),
                              currency: _draft.currency,
                              first: i == 0,
                              expanded: _expandedId == _ids[i],
                              isWinner: _draft.rouletteWinnerId == _ids[i],
                              onTap: () {
                                AppHaptics.selection();
                                setState(
                                  () => _expandedId = _expandedId == _ids[i]
                                      ? null
                                      : _ids[i],
                                );
                              },
                              onEdit: () => _editShare(_ids[i]),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    key: const ValueKey('summary_split_method'),
                    icon: Icons.call_split_rounded,
                    title: 'bf_summary_split_method'.tr(),
                    subtitle: 'bf_split_seg_${_draft.method.wireName}'.tr(),
                    onTap: _editSplit,
                  ),
                  if (adjusted) ...[
                    const SizedBox(height: 12),
                    _ActionCard(
                      key: const ValueKey('summary_reset'),
                      icon: Icons.undo_rounded,
                      title: 'bf_summary_reset_title'.tr(),
                      subtitle: 'bf_summary_reset_body'.tr(),
                      onTap: _resetShares,
                    ),
                  ],
                  if (widget.participants.length > 1) ...[
                    const SizedBox(height: 12),
                    _ActionCard(
                      key: const ValueKey('summary_roulette'),
                      icon: Icons.donut_large_rounded,
                      title: 'bill_roulette'.tr(),
                      subtitle: 'bf_summary_roulette_body'.tr(),
                      onTap: _roulette,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: _isCreating
                  ? SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: null,
                        style: FilledButton.styleFrom(
                          disabledBackgroundColor: p.inverseSurface,
                          shape: const StadiumBorder(),
                        ),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: p.onInverseSurface,
                            semanticsLabel: 'bf_summary_saving'.tr(),
                          ),
                        ),
                      ),
                    )
                  : AssignPillButton(
                      key: const ValueKey('summary_save'),
                      label: 'bf_summary_save'.tr(),
                      muted: !c.isValid,
                      onPressed: _save,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChargesLine extends StatelessWidget {
  const _ChargesLine({required this.draft});

  final BillDraft draft;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    String m(int v) => formatMoneyMinor(v, draft.currency);
    String part(String key, int v) => key.tr(namedArgs: {'amount': m(v)});
    final parts = <String>[
      part('bf_summary_items_part', draft.itemsSubtotalMinor),
      if (draft.taxMinor > 0) part('bf_summary_tax_part', draft.taxMinor),
      if (draft.serviceMinor > 0)
        part('bf_summary_service_part', draft.serviceMinor),
      if (draft.tipMinor > 0) part('bf_summary_tip_part', draft.tipMinor),
      if (draft.deliveryMinor > 0)
        part('bf_summary_delivery_part', draft.deliveryMinor),
      if (draft.otherChargesMinor > 0)
        part('bf_summary_other_part', draft.otherChargesMinor),
      if (draft.discountMinor > 0)
        part('bf_summary_discount_part', draft.discountMinor),
    ];
    return Text(
      parts.join(' · '),
      style: AppTypography.bodySmall.copyWith(
        fontSize: 13,
        color: p.textSecondary,
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    super.key,
    required this.participant,
    required this.name,
    required this.breakdown,
    required this.currency,
    required this.first,
    required this.expanded,
    required this.isWinner,
    required this.onTap,
    required this.onEdit,
  });

  final Map<String, dynamic> participant;
  final String name;
  final PersonBreakdown breakdown;
  final String currency;
  final bool first;
  final bool expanded;
  final bool isWinner;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduce = AppMotion.reduceMotion(context);
    return Container(
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: p.borderSubtle)),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: 'bf_summary_person_semantics'.tr(
              namedArgs: {
                'name': name,
                'amount': formatMoneyMinor(breakdown.totalMinor, currency),
              },
            ),
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      PersonAvatar(participant: participant, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleSmall.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: p.textPrimary,
                                  ),
                                ),
                              ),
                              if (isWinner) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: p.oweSoft,
                                    borderRadius: AppRadii.chipRadius,
                                  ),
                                  child: Text(
                                    'bf_summary_pays_all'.tr(),
                                    style: AppTypography.labelSmall.copyWith(
                                      color: p.oweInk,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      MoneyText(
                        minor: breakdown.totalMinor,
                        currency: currency,
                        tone: MoneyTone.neutral,
                        showSymbol: false,
                        animate: true,
                        animateFromZero: false,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: reduce ? Duration.zero : AppMotion.fast,
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (reduce)
            expanded
                ? Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      64,
                      0,
                      16,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BillBreakdownCard(
                          breakdown: breakdown,
                          currency: currency,
                          bordered: false,
                          showTotal: false,
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton.icon(
                            key: ValueKey('summary_edit_${breakdown.id}'),
                            onPressed: onEdit,
                            style: TextButton.styleFrom(
                              foregroundColor: p.accent,
                              minimumSize: const Size(44, 44),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: Text('bf_summary_edit_share'.tr()),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity)
          else
            AnimatedSize(
              duration: AppMotion.medium,
              curve: AppMotion.quiet,
              alignment: AlignmentDirectional.topStart,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        64,
                        0,
                        16,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BillBreakdownCard(
                            breakdown: breakdown,
                            currency: currency,
                            bordered: false,
                            showTotal: false,
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              key: ValueKey('summary_edit_${breakdown.id}'),
                              onPressed: onEdit,
                              style: TextButton.styleFrom(
                                foregroundColor: p.accent,
                                minimumSize: const Size(44, 44),
                                padding: EdgeInsets.zero,
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: Text('bf_summary_edit_share'.tr()),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: AppRadii.cardShape(p.hairline),
      child: InkWell(
        customBorder: AppRadii.cardShape(p.hairline),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: p.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleSmall.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        fontSize: 13,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: p.textSecondary,
                textDirection: Directionality.of(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit tax, service, tip, delivery and discount, in minor units.
class _ChargesSheet extends StatefulWidget {
  const _ChargesSheet({required this.draft});

  final BillDraft draft;

  @override
  State<_ChargesSheet> createState() => _ChargesSheetState();
}

class _ChargesSheetState extends State<_ChargesSheet> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    final decimals = currencyDecimals(d.currency);
    String text(int minor) => minor == 0
        ? ''
        : fromMinorUnits(minor, d.currency).toStringAsFixed(decimals);
    _c = {
      'tax_vat': TextEditingController(text: text(d.taxMinor)),
      'service_charge': TextEditingController(text: text(d.serviceMinor)),
      'tip': TextEditingController(text: text(d.tipMinor)),
      'delivery_fee': TextEditingController(text: text(d.deliveryMinor)),
      'discount': TextEditingController(text: text(d.discountMinor)),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  BillDraft _result() {
    final cur = widget.draft.currency;
    int v(String k) => minorFromAny(_c[k]!.text, cur).abs();
    return widget.draft.copyWith(
      taxMinor: v('tax_vat'),
      serviceMinor: v('service_charge'),
      tipMinor: v('tip'),
      deliveryMinor: v('delivery_fee'),
      discountMinor: v('discount'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final decimals = currencyDecimals(widget.draft.currency);
    final preview = _result();
    final tooLarge = preview.grandTotalMinor < 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: p.borderStrong,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'bf_summary_charges_title'.tr(),
                style: AppTypography.headlineSmall.copyWith(
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              for (final e in _c.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key.tr(),
                          style: AppTypography.bodyLarge.copyWith(
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          key: ValueKey('charge_${e.key}'),
                          controller: e.value,
                          onChanged: (_) => setState(() {}),
                          textAlign: TextAlign.end,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: decimals > 0,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: formatMoneyMinor(
                              0,
                              widget.draft.currency,
                              showSymbol: false,
                            ),
                            suffixText: ' ${widget.draft.currency}',
                            border: const OutlineInputBorder(
                              borderRadius: AppRadii.rowRadius,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (tooLarge)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'bf_split_discount_too_large'.tr(),
                    style: AppTypography.bodySmall.copyWith(color: p.oweInk),
                  ),
                ),
              Row(
                children: [
                  Text(
                    'total'.tr(),
                    style: AppTypography.titleSmall.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  MoneyText(
                    minor: preview.grandTotalMinor,
                    currency: preview.currency,
                    tone: MoneyTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AssignPillButton(
                key: const ValueKey('charges_save'),
                label: 'bf_summary_charges_save'.tr(),
                muted: tooLarge,
                onPressed: tooLarge
                    ? null
                    : () => Navigator.of(context).pop(_result()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
