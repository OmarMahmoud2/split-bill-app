import 'package:split_bill_app/services/analytics_service.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:split_bill_app/services/export_service.dart';
import 'package:split_bill_app/widgets/bill_details/pay_methods_list.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart'
    show minorFromAny;
import 'package:split_bill_app/services/pdf_font_fallback.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/bill_flow/group_settlement.dart';
import 'package:split_bill_app/bill_flow/share_links.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/edit_bill_screen.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_breakdown_card.dart';
import 'package:split_bill_app/widgets/bill_details/bill_details_header.dart';
import 'package:split_bill_app/widgets/bill_details/bill_history_card.dart';
import 'package:split_bill_app/widgets/bill_details/bill_loading_skeleton.dart';
import 'package:split_bill_app/widgets/bill_details/bill_summary_widget.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';
import 'package:split_bill_app/widgets/bill_details/details_modals.dart';
import 'package:split_bill_app/widgets/bill_details/participant_tile.dart';
import 'package:split_bill_app/widgets/bill_details/proof_card.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

import 'services/notification_service.dart';

/// "d MMM" in the app locale, falling back to English.
String formatBillDate(BuildContext context, DateTime date) {
  try {
    return DateFormat.MMMd(context.locale.toLanguageTag()).format(date);
  } catch (_) {
    return DateFormat.MMMd('en').format(date);
  }
}

/// Bill, host view (v3 Bills board 1): who paid, what is collected, proofs
/// to confirm, and the reminder.
class BillDetailsScreen extends StatefulWidget {
  final String billId;
  final String billName;

  const BillDetailsScreen({
    super.key,
    required this.billId,
    required this.billName,
  });

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _stream;
  final Set<String> _busy = {};
  bool _reminding = false;

  /// Cache-only snapshots for a while mean we are offline.
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

  String get _billName => widget.billName;

  // ------------------------------------------------------------- actions

  void _showError(Object error, {VoidCallback? retry}) {
    if (!mounted) return;
    AppToast.show(
      context,
      message: billErrorKey(error).tr(),
      type: AppToastType.error,
      actionLabel: retry == null ? null : 'feedback_try_again'.tr(),
      onAction: retry,
    );
  }

  /// Marks [participantId] paid (or not), in a transaction on fresh data,
  /// and logs it in `history`.
  Future<void> _setPaid(
    Map<String, dynamic> participant, {
    required bool paid,
    required Map<String, dynamic> bill,
  }) async {
    final id = participant['id']?.toString() ?? '';
    final name = participant['name']?.toString() ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    AppHaptics.selection();
    // Group ledgers count settle-up payments, so marking a member paid also
    // records (or, when unmarking, removes) the matching payment.
    final ledger = LedgerRepository.instance;
    final settlement = paid
        ? groupSettlementForPaidShare(
            billId: widget.billId,
            bill: bill,
            participant: participant,
            createdBy: _user?.uid ?? '',
          )
        : null;
    // A reopened share (paid, then raised by an edit) records a new payment
    // for the difference instead of reusing the first one.
    final previousSettlementId =
        paid && BillReader(bill).paidMinorOf(participant) > 0
        ? ''
        : participant[settlementPaymentIdField]?.toString() ?? '';
    final plan = planSettlementLink(
      paid: paid,
      previousId: previousSettlementId,
      hasSettlement: settlement != null,
    );
    String? recordedId;
    var deleteSucceeded = true;
    try {
      if (plan.recordNew && settlement != null) {
        recordedId = await ledger.recordPayment(settlement);
      }
      if (plan.deleteId != null) {
        final groupId = bill['groupId']?.toString();
        try {
          await ledger.deletePayment(
            PaymentRecord(
              id: plan.deleteId!,
              from: id,
              to: bill['hostId']?.toString() ?? '',
              amountMinor: 0,
              currency: BillReader(bill).currency,
              createdBy: _user?.uid ?? '',
              groupId: groupId,
            ),
          );
        } catch (_) {
          // Older than the 24 h delete window: the payment stays in the
          // group ledger and the share keeps its link, so marking it paid
          // again reuses that payment instead of recording a second one.
          deleteSucceeded = false;
        }
      }
      final settlementId = nextSettlementPaymentId(
        paid: paid,
        previousId: previousSettlementId,
        recordedId: recordedId,
        deleteSucceeded: deleteSucceeded,
      );
      Map<String, dynamic>? after;
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(_billRef);
        final data = snap.data();
        if (data == null) {
          throw FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
        }
        final participants = updateParticipant(
          (data['participants'] as List?) ?? const [],
          id,
          (p) => {
            ...(paid ? p : (Map<String, dynamic>.of(p)..remove('paidMinor'))),
            'status': paid ? 'PAID' : 'PENDING',
            'isPaid': paid,
            if (paid) 'paidMinor': BillReader(data).shareMinorOf(p),
            if (paid) 'paidConfirmedAt': Timestamp.now(),
            if (settlementId != null || !paid)
              settlementPaymentIdField: settlementId,
          },
        );
        final update = <String, dynamic>{
          'participants': participants,
          if (paid)
            'history': appendHistory(data['history'] as List?, [
              BillHistoryEntry(
                by: _user?.uid ?? '',
                byName: _user?.displayName,
                at: DateTime.now(),
                change: 'marked_paid',
                args: {'name': name},
              ),
            ]),
        };
        tx.update(_billRef, update);
        after = {...data, ...update};
      });
      if (paid) AnalyticsService.instance.paymentMarkedPaid('host');
      if (!mounted) return;
      final summary = collectionSummary(
        BillReader(after ?? bill),
        hostId: bill['hostId']?.toString(),
      );
      if (paid && summary.allSettled) {
        unawaited(
          SuccessScreen.show(
            context,
            title: 'bf_bill_settled_title'.tr(),
            message: 'bf_bill_settled_message'.tr(
              namedArgs: {'store': _storeName(bill)},
            ),
            rollFromMinor: summary.owedMinor,
            amountMinor: 0,
            currency: BillReader(bill).currency,
            celebrate: true,
            primaryLabel: 'bf_bill_done'.tr(),
            onPrimary: () => Navigator.of(context).pop(),
          ),
        );
      } else {
        AppToast.show(
          context,
          message:
              (paid
                      ? 'bf_bill_marked_paid'
                      : deleteSucceeded
                      ? 'bf_bill_marked_unpaid'
                      : 'bf_bill_marked_unpaid_payment_kept')
                  .tr(namedArgs: {'name': name}),
          type: paid ? AppToastType.success : AppToastType.info,
        );
      }
      if (paid && !isGuestParticipant(participant)) {
        unawaited(_notifyAccepted(id));
      }
    } catch (e) {
      if (settlement != null && recordedId != null) {
        // The bill update failed: undo the payment so nothing counts twice.
        unawaited(
          ledger
              .deletePayment(
                PaymentRecord(
                  id: recordedId,
                  from: settlement.from,
                  to: settlement.to,
                  amountMinor: settlement.amountMinor,
                  currency: settlement.currency,
                  createdBy: settlement.createdBy,
                  groupId: settlement.groupId,
                ),
              )
              .catchError((_) {}),
        );
      }
      _showError(
        e,
        retry: () => _setPaid(participant, paid: paid, bill: bill),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _notifyAccepted(String uid) async {
    try {
      await NotificationService().sendNotification(
        targetUid: uid,
        title: 'payment_accepted'.tr(),
        body: 'payment_accepted_body'.tr(namedArgs: {'bill_name': _billName}),
        historyTitleKey: 'payment_accepted',
        historyBodyKey: 'payment_accepted_body',
        historyBodyArgs: {'bill_name': _billName},
        data: {
          'billId': widget.billId,
          'type': 'payment_accepted',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );
    } catch (e) {
      // The payment is confirmed either way; the push is best effort.
      debugPrint('payment_accepted notification failed: $e');
    }
  }

  /// Push reminder for app users; personal link for guests.
  Future<void> _remind(
    Map<String, dynamic> participant,
    Map<String, dynamic> bill,
  ) async {
    if (isGuestParticipant(participant)) {
      return _sharePerson(participant, bill);
    }
    if (_reminding) return;
    final reader = BillReader(bill);
    final id = participant['id'].toString();
    final name = participant['name']?.toString() ?? '';
    final amount = formatMoneyMinor(
      reader.outstandingMinorOf(participant),
      reader.currency,
    );
    setState(() => _reminding = true);
    AppHaptics.light();
    try {
      final sent = await NotificationService().sendNotification(
        targetUid: id,
        title: 'reminder_title'.tr(namedArgs: {'bill_name': _billName}),
        body: 'reminder_body'.tr(namedArgs: {'amount': amount}),
        historyTitleKey: 'reminder_title',
        historyBodyKey: 'reminder_body',
        historyTitleArgs: {'bill_name': _billName},
        historyBodyArgs: {'amount': amount},
        data: {'billId': widget.billId},
      );
      if (!mounted) return;
      if (!sent) {
        AppToast.show(
          context,
          message: 'bf_bill_remind_failed'.tr(namedArgs: {'name': name}),
          type: AppToastType.error,
          actionLabel: 'bf_bill_share_link'.tr(),
          onAction: () => _sharePerson(participant, bill),
        );
        return;
      }
      AppToast.show(
        context,
        message: 'bf_bill_reminder_sent'.tr(namedArgs: {'name': name}),
        type: AppToastType.success,
      );
      // Remember the nudge for "last nudge 3 days ago". Best effort.
      try {
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(_billRef);
          final data = snap.data();
          if (data == null) return;
          tx.update(_billRef, {
            'participants': updateParticipant(
              (data['participants'] as List?) ?? const [],
              id,
              (p) => {...p, 'lastRemindedAt': Timestamp.now()},
            ),
          });
        });
      } catch (e) {
        debugPrint('lastRemindedAt not saved: $e');
      }
    } catch (e) {
      _showError(e, retry: () => _remind(participant, bill));
    } finally {
      if (mounted) setState(() => _reminding = false);
    }
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share(String text, String subject, String url) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          sharePositionOrigin: _shareOrigin(),
        ),
      );
      AnalyticsService.instance.billShared('system_share');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bf_bill_share_failed_copied'.tr(),
        type: AppToastType.info,
      );
    }
  }

  Future<void> _shareTable(Map<String, dynamic> bill) async {
    AppHaptics.light();
    final url = personalBillUrl(widget.billId);
    final store = _storeName(bill);
    await _share(
      'bf_bill_share_table_message'.tr(namedArgs: {'store': store, 'url': url}),
      store,
      url,
    );
  }

  Future<void> _sharePdf(Map<String, dynamic> bill) async {
    AppHaptics.light();
    final rtl = Directionality.of(context) == ui.TextDirection.rtl;
    // Fonts can take a few seconds to load: show a spinner meanwhile.
    final nav = Navigator.of(context, rootNavigator: true);
    var spinnerUp = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ).whenComplete(() => spinnerUp = false);
    void hideSpinner() {
      if (spinnerUp) {
        spinnerUp = false;
        nav.pop();
      }
    }

    try {
      final reader = BillReader(bill);
      final cur = reader.currency;
      String money(int m) => formatMoneyMinor(m, cur);
      final hostId = bill['hostId']?.toString();
      final host = reader.participants
          .where((p) => p['id']?.toString() == hostId)
          .firstOrNull;
      final date = dateFromAny(bill['date']);
      final receipt = BillReceipt(
        title: _storeName(bill),
        dateText: date == null ? '' : formatBillDate(context, date),
        totalText: money(reader.totalMinor),
        paidByText: host == null
            ? ''
            : 'bd2_pdf_paid_by'.tr(namedArgs: {'name': '${host['name']}'}),
        itemsHeading: 'bd2_pdf_items'.tr(),
        sharesHeading: 'bd2_pdf_shares'.tr(),
        methodsHeading: 'bd2_pdf_pay_to'.tr(),
        paidLabel: 'bf_bill_status_paid'.tr(),
        notPaidLabel: 'bf_bill_status_not_yet'.tr(),
        items: [
          for (final i in reader.items)
            (
              '${i['name'] ?? ''}',
              money(
                minorFromAny(i['price'], cur) *
                    ((i['qty'] as num?)?.round() ?? 1),
              ),
            ),
        ],
        people: [
          for (final p in reader.participants)
            BillReceiptPerson(
              '${p['name'] ?? ''}',
              money(reader.shareMinorOf(p)),
              p['id']?.toString() == hostId || payStatusOf(p) == PayStatus.paid,
            ),
        ],
        methods: [
          for (final m in payMethodsFor(bill: bill))
            if (m.value.trim().isNotEmpty) (m.label, m.value.trim()),
        ],
      );
      final fonts = await PdfFontFallback().load(
        [
          receipt.title,
          for (final p in receipt.people) p.name,
          for (final i in receipt.items) i.$1,
          for (final m in receipt.methods) m.$1,
          receipt.paidByText,
          receipt.paidLabel,
          receipt.notPaidLabel,
        ].join(' '),
      );
      final bytes = await ExportService.buildBillReceiptPdf(
        receipt,
        font: pw.Font.ttf(
          await rootBundle.load('assets/fonts/Inter/Inter-Regular.ttf'),
        ),
        boldFont: pw.Font.ttf(
          await rootBundle.load('assets/fonts/Inter/Inter-Bold.ttf'),
        ),
        fontFallback: fonts.fonts,
        rtl: rtl,
      );
      final dir = await getTemporaryDirectory();
      // Readable file name in the share sheet and Files.
      final safe = receipt.title
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
          .trim();
      final file = File(
        '${dir.path}/${safe.isEmpty ? 'Evens' : '$safe · Evens'}.pdf',
      );
      await file.writeAsBytes(bytes);
      hideSpinner();
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: receipt.title),
      );
    } catch (e) {
      hideSpinner();
      debugPrint('Bill PDF failed: $e');
      if (mounted) {
        AppToast.show(
          context,
          message: 'exp_failed'.tr(),
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _sharePerson(
    Map<String, dynamic> participant,
    Map<String, dynamic> bill,
  ) async {
    AppHaptics.light();
    final reader = BillReader(bill);
    final id = participant['id']?.toString() ?? '';
    final url = personalBillUrl(widget.billId, participantId: id);
    final store = _storeName(bill);
    await _share(
      'bf_bill_share_person_message'.tr(
        namedArgs: {
          'name': participant['name']?.toString() ?? '',
          'store': store,
          'amount': formatMoneyMinor(
            reader.outstandingMinorOf(participant),
            reader.currency,
          ),
          'url': url,
        },
      ),
      store,
      url,
    );
  }

  Future<void> _delete() async {
    final confirmed = await BillDetailsModals.confirmDelete(context);
    if (!confirmed || !mounted) return;
    AppHaptics.warning();
    try {
      await _billRef.delete();
      if (!mounted) return;
      final navigator = Navigator.of(context);
      AppToast.show(
        context,
        message: 'bf_bill_deleted'.tr(),
        type: AppToastType.success,
      );
      navigator.pop();
    } catch (e) {
      _showError(e, retry: _delete);
    }
  }

  void _edit(Map<String, dynamic> bill) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditBillScreen(billId: widget.billId, billData: bill),
      ),
    );
  }

  void _showMore(Map<String, dynamic> bill) {
    AppHaptics.selection();
    showLedgerSheet(
      context,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetAction(
              icon: AppIcons.edit,
              label: 'bf_bill_action_edit'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                _edit(bill);
              },
            ),
            _SheetAction(
              icon: AppIcons.receipt,
              label: 'bf_bill_action_full_bill'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                BillDetailsModals.showFullBillDetails(context, bill);
              },
            ),
            _SheetAction(
              icon: AppIcons.share,
              label: 'bf_bill_action_share_table'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                _shareTable(bill);
              },
            ),
            if (!kIsWeb)
              _SheetAction(
                icon: AppIcons.receipt,
                label: 'bd2_share_pdf'.tr(),
                onTap: () {
                  Navigator.of(context).pop();
                  _sharePdf(bill);
                },
              ),
            _SheetAction(
              icon: AppIcons.delete,
              label: 'bf_bill_action_delete'.tr(),
              destructive: true,
              onTap: () {
                Navigator.of(context).pop();
                _delete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showParticipantActions(
    Map<String, dynamic> participant,
    Map<String, dynamic> bill,
  ) {
    AppHaptics.selection();
    final reader = BillReader(bill);
    final status = payStatusOf(participant);
    final name = participant['name']?.toString() ?? '';
    final proof = decodeProofImage(participant['paymentProof']);
    final p = context.palette;
    showLedgerSheet(
      context,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BillAvatar(
                  name: name,
                  photoUrl: participant['photoUrl']?.toString(),
                  tintKey: participant['id']?.toString(),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    name,
                    style: AppTypography.titleLarge.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
                PayStatusPill(status: status, hasProof: proof != null),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Flexible(
              child: SingleChildScrollView(
                child: BillBreakdownCard(
                  breakdown: reader.breakdownFor(
                    participant['id']?.toString() ?? '',
                  ),
                  currency: reader.currency,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (status != PayStatus.paid)
              _SheetAction(
                icon: AppIcons.success,
                label: 'bf_bill_action_mark_paid'.tr(),
                onTap: () {
                  Navigator.of(context).pop();
                  _setPaid(participant, paid: true, bill: bill);
                },
              )
            else
              _SheetAction(
                icon: AppIcons.undo,
                label: 'bf_bill_action_mark_unpaid'.tr(),
                onTap: () {
                  Navigator.of(context).pop();
                  _setPaid(participant, paid: false, bill: bill);
                },
              ),
            if (proof != null)
              _SheetAction(
                icon: AppIcons.gallery,
                label: 'bf_bill_action_view_proof'.tr(),
                onTap: () {
                  Navigator.of(context).pop();
                  _viewProof(participant, proof, bill);
                },
              ),
            if (status != PayStatus.paid && !isGuestParticipant(participant))
              _SheetAction(
                icon: AppIcons.bell,
                label: 'bf_bill_action_remind'.tr(),
                onTap: () {
                  Navigator.of(context).pop();
                  _remind(participant, bill);
                },
              ),
            _SheetAction(
              icon: AppIcons.link,
              label: 'bf_bill_action_share_person'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                _sharePerson(participant, bill);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Host rejects a submitted proof: clears it and sets the share back to
  /// unpaid, after confirming.
  Future<void> _rejectProof(Map<String, dynamic> participant) async {
    final id = participant['id']?.toString() ?? '';
    final name = participant['name']?.toString() ?? '';
    if (id.isEmpty || _busy.contains(id)) return;
    final ok = await showAppDialog(
      context,
      icon: AppIcons.cancel,
      title: 'bf_bill_proof_reject_title'.tr(),
      message: 'bf_bill_proof_reject_body'.tr(namedArgs: {'name': name}),
      confirmLabel: 'bf_bill_proof_reject'.tr(),
      destructive: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _busy.add(id));
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(_billRef);
        final data = snap.data();
        if (data == null) {
          throw FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
        }
        tx.update(_billRef, {
          'participants': updateParticipant(
            (data['participants'] as List?) ?? const [],
            id,
            rejectProof,
          ),
        });
      });
      AnalyticsService.instance.proofRejected();
      if (!mounted) return;
      AppToast.show(
        context,
        message: 'bf_bill_proof_rejected'.tr(namedArgs: {'name': name}),
        type: AppToastType.info,
      );
    } catch (e) {
      _showError(e, retry: () => _rejectProof(participant));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _viewProof(
    Map<String, dynamic> participant,
    Uint8List image,
    Map<String, dynamic> bill,
  ) {
    BillDetailsModals.showProof(
      context,
      name: participant['name']?.toString() ?? '',
      image: image,
      onConfirm: () => _setPaid(participant, paid: true, bill: bill),
    );
  }

  String _storeName(Map<String, dynamic> bill) {
    final s = bill['storeName']?.toString().trim();
    return (s == null || s.isEmpty) ? _billName : s;
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
            return SafeArea(
              child: Column(
                children: [
                  const BillDetailsHeader(),
                  Expanded(
                    child: isOfflineError(error)
                        ? ErrorState.offline(onRetry: retry)
                        : ErrorState(
                            title: 'bf_bill_load_error_title'.tr(),
                            message: billErrorKey(error).tr(),
                            onRetry: retry,
                          ),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) return const BillLoadingSkeleton();
          final doc = snapshot.data!;
          _trackOffline(doc.metadata.isFromCache);
          final data = doc.data();
          if (!doc.exists || data == null) {
            return SafeArea(
              child: Column(
                children: [
                  const BillDetailsHeader(),
                  Expanded(
                    child: ErrorState(
                      icon: AppIcons.receipt,
                      title: 'bf_bill_not_found_title'.tr(),
                      message: 'bf_bill_not_found_message'.tr(),
                      retryLabel: 'bf_bill_go_back'.tr(),
                      onRetry: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            );
          }
          return _buildBill(context, data);
        },
      ),
    );
  }

  Widget _buildBill(BuildContext context, Map<String, dynamic> bill) {
    final p = context.palette;
    final reader = BillReader(bill);
    final currency = reader.currency;
    final hostId = bill['hostId']?.toString();
    final amIHost = hostId != null && hostId == _user?.uid;
    final summary = collectionSummary(reader, hostId: hostId);
    final now = DateTime.now();

    final metaNoStore = <String>[
      if (dateFromAny(bill['date']) case final date?)
        formatBillDate(context, date),
      if (bill['groupName']?.toString().trim().isNotEmpty == true)
        bill['groupName'].toString().trim(),
    ].join(' · ');

    final others = [
      for (final pt in reader.participants)
        if (pt['id']?.toString() != hostId) pt,
    ];
    final reviews = [
      for (final pt in others)
        if (payStatusOf(pt) == PayStatus.review) pt,
    ];
    final toRemind = amIHost ? nextToRemind(reader, hostId: hostId) : null;
    final history = reader.history;

    var index = 0;
    Widget entrance(Widget child) =>
        StaggeredEntrance(index: index++, child: child);

    final children = <Widget>[
      entrance(
        BillSummaryWidget(
          title: _storeName(bill),
          paidByName: reader.participants
              .where((x) => x['id']?.toString() == hostId)
              .firstOrNull?['name']
              ?.toString(),
          paidByPhotoUrl: reader.participants
              .where((x) => x['id']?.toString() == hostId)
              .firstOrNull?['photoUrl']
              ?.toString(),
          paidById: hostId,
          metaLine: metaNoStore,
          totalMinor: reader.totalMinor,
          currency: currency,
          summary: summary,
        ),
      ),
      if (others.isNotEmpty)
        entrance(
          _Card(
            margin: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
            child: Column(
              children: [
                for (var i = 0; i < others.length; i++)
                  ParticipantTile(
                    name: others[i]['name']?.toString() ?? '',
                    photoUrl: others[i]['photoUrl']?.toString(),
                    tintKey: others[i]['id']?.toString(),
                    shareMinor: payStatusOf(others[i]) == PayStatus.paid
                        ? reader.shareMinorOf(others[i])
                        : reader.outstandingMinorOf(others[i]),
                    currency: currency,
                    status: payStatusOf(others[i]),
                    hasProof:
                        decodeProofImage(others[i]['paymentProof']) != null,
                    showDivider: i > 0,
                    onTap: amIHost
                        ? () => _showParticipantActions(others[i], bill)
                        : () => BillDetailsModals.showUserShareDetails(
                            context,
                            others[i],
                            bill,
                          ),
                  ),
              ],
            ),
          ),
        ),
      if (amIHost)
        for (final pt in reviews)
          entrance(
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
              child: Builder(
                builder: (context) {
                  final proof = decodeProofImage(pt['paymentProof']);
                  final detail = [
                    if (pt['paymentMethod']?.toString().trim().isNotEmpty ==
                        true)
                      pt['paymentMethod'].toString().trim(),
                    if (dateFromAny(pt['paymentTime']) case final t?)
                      resolveCopy(relativeTimeCopy(t, now)),
                  ].join(' · ');
                  return ProofCard(
                    name: pt['name']?.toString() ?? '',
                    image: proof,
                    detail: detail,
                    busy: _busy.contains(pt['id']?.toString()),
                    onViewProof: proof == null
                        ? null
                        : () => _viewProof(pt, proof, bill),
                    onConfirm: () => _setPaid(pt, paid: true, bill: bill),
                    onReject: () => _rejectProof(pt),
                  );
                },
              ),
            ),
          ),
      entrance(
        _Card(
          margin: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
          child: InkWell(
            onTap: () => BillDetailsModals.showFullBillDetails(context, bill),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(AppIcons.receipt, color: p.textSecondary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'bf_bill_full_bill_row'.tr(),
                      style: AppTypography.titleSmall.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(AppIcons.chevronRight, color: p.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
      if (history.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 8),
          child: Text(
            'bf_bill_history_title'.tr(),
            style: AppTypography.labelMedium.copyWith(
              color: p.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        entrance(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: BillHistoryCard(
              entries: history,
              currency: currency,
              currentUid: _user?.uid,
              now: now,
            ),
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.xxl),
    ];

    String? remindLabel;
    if (toRemind != null) {
      final name = toRemind['name']?.toString() ?? '';
      final last = dateFromAny(toRemind['lastRemindedAt']);
      final base = isGuestParticipant(toRemind)
          ? 'bf_bill_send_link_to'.tr(namedArgs: {'name': name})
          : 'bf_bill_remind_name'.tr(namedArgs: {'name': name});
      remindLabel = last == null
          ? base
          : 'bf_bill_remind_with_last'.tr(
              namedArgs: {
                'action': base,
                'when': resolveCopy(relativeTimeCopy(last, now)),
              },
            );
    }

    return SafeArea(
      child: Column(
        children: [
          BillDetailsHeader(
            actions: [
              BillCircleButton(
                icon: AppIcons.share,
                semanticLabel: 'bf_bill_share_semantics'.tr(),
                onTap: () => _shareTable(bill),
              ),
              if (amIHost)
                BillCircleButton(
                  icon: AppIcons.more,
                  semanticLabel: 'bf_bill_more_semantics'.tr(),
                  onTap: () => _showMore(bill),
                ),
            ],
          ),
          OfflineBanner(
            visible: _offline,
            margin: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
          ),
          Expanded(child: ListView(children: children)),
          if (remindLabel != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
              child: BillPillButton(
                label: remindLabel,
                ghost: true,
                busy: _reminding,
                onPressed: () => _remind(toRemind!, bill),
              ),
            ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.margin});

  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.hairline),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = destructive ? p.error : p.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadii.rowRadius,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Text(
                label,
                style: AppTypography.titleSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
