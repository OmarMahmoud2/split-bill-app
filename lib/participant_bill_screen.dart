import 'package:split_bill_app/services/analytics_service.dart';
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/screens/guest_bill/guest_bill_repository.dart';
import 'package:split_bill_app/services/public_profile_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_details_header.dart';
import 'package:split_bill_app/widgets/bill_details/bill_loading_skeleton.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';
import 'package:split_bill_app/widgets/bill_details/participant_bill_view.dart';
import 'package:split_bill_app/widgets/bill_details/pay_methods_list.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

import 'services/notification_service.dart';

/// Bill, participant view: your exact share (from the bill's own numbers,
/// via [BillReader.breakdownFor]), how to pay the host, and "I've paid".
class ParticipantBillScreen extends StatefulWidget {
  final String billId;
  final String billName;

  const ParticipantBillScreen({
    super.key,
    required this.billId,
    required this.billName,
  });

  @override
  State<ParticipantBillScreen> createState() => _ParticipantBillScreenState();
}

class _ParticipantBillScreenState extends State<ParticipantBillScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;

  String? _profileHostId;
  Future<Map<String, dynamic>?>? _hostProfile;

  PayMethodEntry? _opening;
  String? _usedMethodLabel;
  bool _submitting = false;

  bool _offline = false;
  Timer? _offlineTimer;

  DocumentReference<Map<String, dynamic>> get _billRef =>
      FirebaseFirestore.instance.collection('bills').doc(widget.billId);

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    _stream = _billRef.snapshots(includeMetadataChanges: true);
  }

  @override
  void dispose() {
    _offlineTimer?.cancel();
    super.dispose();
  }

  void _trackOffline(bool fromCache) {
    if (!fromCache) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      if (_offline) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _offline = false);
        });
      }
      return;
    }
    if (_offline || _offlineTimer != null) return;
    _offlineTimer = Timer(const Duration(seconds: 3), () {
      _offlineTimer = null;
      if (mounted) setState(() => _offline = true);
    });
  }

  /// Cached per host so rebuilds do not refetch.
  Future<Map<String, dynamic>?> _profileFor(String hostId) {
    if (_profileHostId != hostId || _hostProfile == null) {
      _profileHostId = hostId;
      _hostProfile = PublicProfileService.fetch(hostId).catchError((Object e) {
        debugPrint('host profile not loaded: $e');
        return null;
      });
    }
    return _hostProfile!;
  }

  String _storeName(Map<String, dynamic> bill) {
    final s = bill['storeName']?.toString().trim();
    return (s == null || s.isEmpty) ? widget.billName : s;
  }

  String _hostName(Map<String, dynamic> bill) {
    final s = bill['hostName']?.toString().trim();
    return (s == null || s.isEmpty) ? 'bf_bill_host_fallback'.tr() : s;
  }

  // ------------------------------------------------------------- paying

  Future<void> _openMethod(PayMethodEntry entry) async {
    if (_opening != null) return;
    setState(() => _opening = entry);
    AppHaptics.light();
    _usedMethodLabel = entry.name;
    var outcome = PaymentLaunchOutcome.failed;
    try {
      outcome = await const PaymentLauncher().run(entry.launch);
    } catch (e) {
      debugPrint('payment launch failed: $e');
    }
    if (!mounted) return;
    setState(() => _opening = null);
    final launch = entry.launch;
    switch (outcome) {
      case PaymentLaunchOutcome.openedPrefilled:
      case PaymentLaunchOutcome.openedAmountCopied:
        AppToast.show(
          context,
          message: launch.instructionKey.tr(namedArgs: launch.instructionArgs),
        );
      case PaymentLaunchOutcome.copied:
        final copy = launch is DeepLinkLaunch ? launch.fallback : launch;
        AppToast.show(
          context,
          message: copy.instructionKey.tr(namedArgs: copy.instructionArgs),
          type: AppToastType.success,
        );
      case PaymentLaunchOutcome.failed:
        AppToast.show(
          context,
          message: 'bf_bill_pay_failed'.tr(
            namedArgs: {'app': entry.name, 'handle': entry.handle},
          ),
          type: AppToastType.error,
          actionLabel: 'bf_bill_copy'.tr(),
          onAction: () => _copyHandle(entry),
        );
    }
  }

  Future<void> _copyHandle(PayMethodEntry entry) async {
    try {
      await Clipboard.setData(ClipboardData(text: entry.handle));
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bf_bill_handle_copied'.tr(
          namedArgs: {'handle': entry.handle, 'app': entry.name},
        ),
        type: AppToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bf_bill_copy_failed'.tr(namedArgs: {'handle': entry.handle}),
        type: AppToastType.error,
      );
    }
  }

  void _showPaidSheet(Map<String, dynamic> bill) {
    AppHaptics.selection();
    final p = context.palette;
    PremiumBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'bf_bill_paid_sheet_title'.tr(),
            style: AppTypography.titleLarge.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'bf_bill_paid_sheet_message'.tr(
              namedArgs: {'host': _hostName(bill)},
            ),
            style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          BillPillButton(
            label: 'bf_bill_paid_add_proof'.tr(),
            icon: AppIcons.gallery,
            onPressed: () {
              Navigator.of(context).pop();
              _submitPaid(bill, withProof: true);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          BillPillButton(
            label: 'bf_bill_paid_no_proof'.tr(),
            ghost: true,
            onPressed: () {
              Navigator.of(context).pop();
              _submitPaid(bill, withProof: false);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitPaid(
    Map<String, dynamic> bill, {
    required bool withProof,
  }) async {
    final uid = _user?.uid;
    if (uid == null || _submitting) return;

    String? proof;
    if (withProof) {
      try {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 25,
          maxWidth: 800,
        );
        if (image == null) return; // Cancelled: nothing to say.
        proof =
            'data:image/jpeg;base64,${base64Encode(await image.readAsBytes())}';
      } catch (e) {
        debugPrint('proof pick failed: $e');
        if (!mounted) return;
        AppToast.show(
          context,
          message: 'bf_bill_error_photo'.tr(),
          type: AppToastType.error,
          actionLabel: 'bf_bill_paid_no_proof_short'.tr(),
          onAction: () => _submitPaid(bill, withProof: false),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _submitting = true);
    final reader = BillReader(bill);
    final me = reader.participant(uid);
    final shareMinor = me == null ? 0 : reader.outstandingMinorOf(me);
    try {
      // Through the backend, not a direct write: rules only let members write
      // bills of up to 12 participants, and the backend touches this one
      // entry only (matched by uid), whatever the bill size.
      final hostId = bill['hostId']?.toString();
      await FirestoreGuestBillRepository().submitPayment(
        billId: widget.billId,
        participantId: uid,
        proofDataUrl: proof,
        method: _usedMethodLabel,
      );
      AnalyticsService.instance.paymentMarkedPaid('member');
      if (hostId != null) {
        unawaited(
          _notifyHost(
            hostId,
            bill,
            formatMoneyMinor(shareMinor, reader.currency),
            withProof: proof != null,
          ),
        );
      }
      if (!mounted) return;
      setState(() => _submitting = false);
      await SuccessScreen.show(
        context,
        title: 'bf_bill_paid_success_title'.tr(),
        message: 'bf_bill_paid_success_message'.tr(
          namedArgs: {'host': _hostName(bill)},
        ),
        rollFromMinor: shareMinor,
        amountMinor: 0,
        currency: reader.currency,
        primaryLabel: 'bf_bill_done'.tr(),
        onPrimary: () => Navigator.of(context).pop(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.show(
        context,
        message: billErrorKey(e).tr(),
        type: AppToastType.error,
        actionLabel: 'feedback_try_again'.tr(),
        onAction: () => _submitPaid(bill, withProof: withProof),
      );
    }
  }

  Future<void> _notifyHost(
    String hostId,
    Map<String, dynamic> bill,
    String amount, {
    required bool withProof,
  }) async {
    final payer = _user?.displayName ?? 'a_friend'.tr();
    final store = _storeName(bill);
    try {
      if (withProof) {
        final method = _usedMethodLabel;
        final suffix = method == null
            ? ''
            : 'notification_via_method'.tr(namedArgs: {'method': method});
        final args = {
          'payer': payer,
          'amount': amount,
          'store': store,
          'method_suffix': suffix,
        };
        await NotificationService().sendNotification(
          targetUid: hostId,
          title: 'payment_received'.tr(),
          body: 'payment_received_body'.tr(namedArgs: args),
          historyTitleKey: 'payment_received',
          historyBodyKey: 'payment_received_body',
          historyBodyArgs: args,
          data: {
            'billId': widget.billId,
            'type': 'payment_proof',
            'amount': amount,
            'method': method ?? 'unknown',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
        );
      } else {
        final args = {'payer': payer, 'amount': amount};
        await NotificationService().sendNotification(
          targetUid: hostId,
          title: 'payment_marked_as_sent'.tr(),
          body: 'payment_marked_as_sent_body'.tr(namedArgs: args),
          historyTitleKey: 'payment_marked_as_sent',
          historyBodyKey: 'payment_marked_as_sent_body',
          historyBodyArgs: args,
          data: {'billId': widget.billId, 'type': 'payment_proof'},
        );
      }
    } catch (e) {
      // Marked paid either way; the host also sees it on the bill.
      debugPrint('host notification failed: $e');
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.canvas,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error!;
            void retry() => setState(_subscribe);
            return _withBack(
              isOfflineError(error)
                  ? ErrorState.offline(onRetry: retry)
                  : ErrorState(
                      title: 'bf_bill_load_error_title'.tr(),
                      message: billErrorKey(error).tr(),
                      onRetry: retry,
                    ),
            );
          }
          if (!snapshot.hasData) return const BillLoadingSkeleton();
          final doc = snapshot.data!;
          _trackOffline(doc.metadata.isFromCache);
          final bill = doc.data();
          if (!doc.exists || bill == null) {
            return _withBack(
              ErrorState(
                icon: AppIcons.receipt,
                title: 'bf_bill_not_found_title'.tr(),
                message: 'bf_bill_not_found_message'.tr(),
                retryLabel: 'bf_bill_go_back'.tr(),
                onRetry: () => Navigator.of(context).maybePop(),
              ),
            );
          }
          final uid = _user?.uid ?? '';
          final reader = BillReader(bill);
          final me = reader.participant(uid);
          if (me == null) {
            return _withBack(
              ErrorState(
                icon: AppIcons.personSearch,
                title: 'bf_bill_not_on_bill_title'.tr(),
                message: 'bf_bill_not_on_bill_message'.tr(),
                retryLabel: 'bf_bill_go_back'.tr(),
                onRetry: () => Navigator.of(context).maybePop(),
              ),
            );
          }
          final status = payStatusOf(me);
          // What is still due; the full share once paid.
          final shareMinor = status == PayStatus.paid
              ? reader.shareMinorOf(me)
              : reader.outstandingMinorOf(me);
          final hostId = bill['hostId']?.toString() ?? '';
          final store = _storeName(bill);

          return SafeArea(
            child: FutureBuilder<Map<String, dynamic>?>(
              future: status == PayStatus.notYet && hostId.isNotEmpty
                  ? _profileFor(hostId)
                  : null,
              builder: (context, profile) {
                final loading =
                    status == PayStatus.notYet &&
                    hostId.isNotEmpty &&
                    profile.connectionState != ConnectionState.done;
                final entries = loading
                    ? const <PayMethodEntry>[]
                    : buildPayMethodEntries(
                        methods: payMethodsFor(
                          hostProfile: profile.data,
                          bill: bill,
                        ),
                        shareMinor: shareMinor,
                        currency: reader.currency,
                        note: store,
                        recipientName: _hostName(bill),
                        message: 'bf_bill_apple_cash_message'.tr(
                          namedArgs: {
                            'amount': formatMoneyMinor(
                              shareMinor,
                              reader.currency,
                            ),
                            'store': store,
                          },
                        ),
                        platform: currentPaymentPlatform(),
                      );
                return ParticipantBillView(
                  hostName: _hostName(bill),
                  storeName: store,
                  currency: reader.currency,
                  breakdown: reader.breakdownFor(uid),
                  shareMinor: shareMinor,
                  status: status,
                  payEntries: entries,
                  payLoading: loading,
                  openingEntry: _opening,
                  onOpenMethod: _openMethod,
                  onPaid: () => _showPaidSheet(bill),
                  submitting: _submitting,
                  offline: _offline,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _withBack(Widget body) => SafeArea(
    child: Column(
      children: [
        const BillDetailsHeader(),
        Expanded(child: body),
      ],
    ),
  );
}
