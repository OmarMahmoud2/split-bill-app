import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/bill_flow/share_links.dart';
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
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

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
    try {
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
            ...p,
            'status': paid ? 'PAID' : 'PENDING',
            'isPaid': paid,
            if (paid) 'paidConfirmedAt': Timestamp.now(),
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
          message: (paid ? 'bf_bill_marked_paid' : 'bf_bill_marked_unpaid').tr(
            namedArgs: {'name': name},
          ),
          type: paid ? AppToastType.success : AppToastType.info,
        );
      }
      if (paid && !isGuestParticipant(participant)) {
        unawaited(_notifyAccepted(id));
      }
    } catch (e) {
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
      reader.shareMinorOf(participant),
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
            reader.shareMinorOf(participant),
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
    PremiumBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetAction(
            icon: Icons.edit_outlined,
            label: 'bf_bill_action_edit'.tr(),
            onTap: () {
              Navigator.of(context).pop();
              _edit(bill);
            },
          ),
          _SheetAction(
            icon: Icons.receipt_long_outlined,
            label: 'bf_bill_action_full_bill'.tr(),
            onTap: () {
              Navigator.of(context).pop();
              BillDetailsModals.showFullBillDetails(context, bill);
            },
          ),
          _SheetAction(
            icon: Icons.ios_share_rounded,
            label: 'bf_bill_action_share_table'.tr(),
            onTap: () {
              Navigator.of(context).pop();
              _shareTable(bill);
            },
          ),
          _SheetAction(
            icon: Icons.delete_outline_rounded,
            label: 'bf_bill_action_delete'.tr(),
            destructive: true,
            onTap: () {
              Navigator.of(context).pop();
              _delete();
            },
          ),
        ],
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
    PremiumBottomSheet.show(
      context: context,
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
              PayStatusPill(status: status),
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
              icon: Icons.check_circle_outline_rounded,
              label: 'bf_bill_action_mark_paid'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                _setPaid(participant, paid: true, bill: bill);
              },
            )
          else
            _SheetAction(
              icon: Icons.undo_rounded,
              label: 'bf_bill_action_mark_unpaid'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                _setPaid(participant, paid: false, bill: bill);
              },
            ),
          if (proof != null)
            _SheetAction(
              icon: Icons.image_outlined,
              label: 'bf_bill_action_view_proof'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                _viewProof(participant, proof, bill);
              },
            ),
          if (status != PayStatus.paid && !isGuestParticipant(participant))
            _SheetAction(
              icon: Icons.notifications_none_rounded,
              label: 'bf_bill_action_remind'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                _remind(participant, bill);
              },
            ),
          _SheetAction(
            icon: Icons.link_rounded,
            label: 'bf_bill_action_share_person'.tr(),
            onTap: () {
              Navigator.of(context).pop();
              _sharePerson(participant, bill);
            },
          ),
        ],
      ),
    );
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
                      icon: Icons.receipt_long_outlined,
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

    final meta = <String>[
      _storeName(bill),
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
          metaLine: meta,
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
                    shareMinor: reader.shareMinorOf(others[i]),
                    currency: currency,
                    status: payStatusOf(others[i]),
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
                  Icon(Icons.receipt_long_outlined, color: p.textSecondary),
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
                  Icon(Icons.chevron_right_rounded, color: p.textTertiary),
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
            'bf_bill_history_title'.tr().toUpperCase(),
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
                icon: Icons.ios_share_rounded,
                semanticLabel: 'bf_bill_share_semantics'.tr(),
                onTap: () => _shareTable(bill),
              ),
              if (amIHost)
                BillCircleButton(
                  icon: Icons.more_horiz_rounded,
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
