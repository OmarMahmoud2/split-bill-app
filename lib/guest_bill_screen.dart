import 'package:split_bill_app/widgets/layout/app_background.dart';
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:split_bill_app/services/analytics_service.dart';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

import 'screens/guest_bill/guest_bill_model.dart';
import 'screens/guest_bill/guest_bill_repository.dart';
import 'screens/guest_bill/guest_selector_view.dart';
import 'screens/guest_bill/widgets/guest_breakdown.dart';
import 'screens/guest_bill/widgets/guest_chrome.dart';
import 'screens/guest_bill/widgets/guest_pay_panel.dart';
import 'screens/guest_bill/widgets/guest_share.dart';
import 'screens/guest_bill/widgets/guest_status_views.dart';

enum _GuestView {
  loading,
  error,
  notFound,
  expired,
  settled,
  picker,
  share,
  waiting,
  confirmed,
}

/// The page a guest lands on from a shared bill link (web and app).
///
/// Flow (v3 GuestFlow): pick your name (skipped for personal `?p=` links)
/// → your share → pay with the host's methods (+ optional screenshot) →
/// "I've paid" success → live status until the host confirms.
class GuestBillScreen extends StatefulWidget {
  const GuestBillScreen({
    super.key,
    required this.billId,
    this.initialParticipantId,
    this.repository,
    this.launcher = const PaymentLauncher(),
    this.clock,
  });

  final String billId;

  /// From a personal link (`?p=`, legacy `?uid=`): skip the name picker.
  final String? initialParticipantId;
  final GuestBillRepository? repository;
  final PaymentLauncher launcher;
  final DateTime Function()? clock;

  @override
  State<GuestBillScreen> createState() => _GuestBillScreenState();
}

class _GuestBillScreenState extends State<GuestBillScreen> {
  late GuestBillRepository _repo =
      widget.repository ?? FirestoreGuestBillRepository();
  StreamSubscription<Map<String, dynamic>?>? _sub;
  Timer? _firstLoadTimer;

  GuestBill? _bill;
  bool _loading = true;
  bool _notFound = false;
  bool _failed = false;

  String? _selectedId;
  bool _declinedLink = false;
  GuestProof? _proof;
  bool _sending = false;
  GuestPayStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.guestLinkOpened();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant GuestBillScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.billId != widget.billId ||
        oldWidget.repository != widget.repository) {
      _repo = widget.repository ?? FirestoreGuestBillRepository();
      _selectedId = null;
      _declinedLink = false;
      _proof = null;
      _lastStatus = null;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _firstLoadTimer?.cancel();
    super.dispose();
  }

  // --------------------------------------------------------------- data

  void _subscribe() {
    _sub?.cancel();
    _firstLoadTimer?.cancel();
    if (widget.billId.trim().isEmpty) {
      _loading = false;
      _notFound = true;
      return;
    }
    _loading = _bill == null;
    _failed = false;
    _firstLoadTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _bill == null && !_notFound) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    });
    _sub = _repo
        .watch(widget.billId)
        .listen(
          _onData,
          onError: (Object _) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _failed = _bill == null;
            });
          },
        );
  }

  void _onData(Map<String, dynamic>? data) {
    _firstLoadTimer?.cancel();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _loading = false;
        _notFound = true;
        _bill = null;
      });
      return;
    }
    final bill = GuestBill.fromMap(
      widget.billId,
      data,
      countryCode: PlatformDispatcher.instance.locale.countryCode,
    );
    final linked = widget.initialParticipantId;
    var selected = _selectedId;
    if (selected == null &&
        !_declinedLink &&
        linked != null &&
        bill.participant(linked) != null &&
        linked != bill.hostId) {
      selected = linked;
    }
    if (selected != null && bill.participant(selected) == null) {
      selected = null;
    }
    final status = bill.participant(selected)?.status;
    final becamePaid =
        selected != null &&
        selected == _selectedId &&
        status == GuestPayStatus.paid &&
        _lastStatus != null &&
        _lastStatus != GuestPayStatus.paid;

    setState(() {
      _bill = bill;
      _loading = false;
      _failed = false;
      _notFound = false;
      _selectedId = selected;
      _lastStatus = status;
    });

    if (becamePaid) _celebrateConfirmed(bill, selected);
  }

  void _celebrateConfirmed(GuestBill bill, String participantId) {
    final breakdown = bill.breakdownFor(participantId);
    final navigator = Navigator.of(context);
    SuccessScreen.show<void>(
      context,
      title: 'guest_confirmed_title'.tr(
        namedArgs: {
          'host': guestHostName(bill),
          'amount': guestAmount(breakdown.totalMinor, bill.currency),
        },
      ),
      message: 'guest_confirmed_message'.tr(
        namedArgs: {'store': guestStoreName(bill)},
      ),
      primaryLabel: 'guest_done'.tr(),
      onPrimary: navigator.pop,
    );
  }

  // ------------------------------------------------------------ actions

  void _select(String id) {
    setState(() {
      _selectedId = id;
      _proof = null;
      _lastStatus = _bill?.participant(id)?.status;
    });
  }

  void _notMe() {
    setState(() {
      _selectedId = null;
      _declinedLink = true;
      _proof = null;
      _lastStatus = null;
    });
  }

  Future<void> _pickProof() async {
    try {
      final proof = await _repo.pickProof();
      if (proof != null && mounted) setState(() => _proof = proof);
    } on GuestProofTooLarge {
      if (mounted) {
        AppToast.show(
          context,
          message: 'guest_screenshot_too_large'.tr(),
          type: AppToastType.error,
        );
      }
    } on Object {
      if (mounted) {
        AppToast.show(
          context,
          message: 'feedback_error_message'.tr(),
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _submit(GuestBill bill, GuestParticipant me) async {
    final proof = _proof;
    setState(() => _sending = true);
    try {
      await _repo.submitPayment(
        billId: bill.id,
        participantId: me.id,
        proofDataUrl: proof?.dataUrl,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.show(
        context,
        message: 'guest_submit_error'.tr(),
        type: AppToastType.error,
        actionLabel: 'feedback_try_again'.tr(),
        onAction: () => _submit(bill, me),
      );
      return;
    }

    final dueMinor = bill.dueMinorFor(me.id);
    final amount = guestAmount(dueMinor, bill.currency);
    final payer = me.name.isEmpty ? 'guest'.tr() : me.name;
    final store = guestStoreName(bill);
    final withProof = proof != null;
    AnalyticsService.instance.guestPaymentSubmitted(withProof: withProof);
    unawaited(
      _repo.notifyHost(
        GuestPaymentNotice(
          billId: bill.id,
          hostId: bill.hostId,
          payerName: payer,
          storeName: store,
          formattedAmount: amount,
          amount: fromMinorUnits(dueMinor, bill.currency),
          withProof: withProof,
          title: withProof
              ? 'payment_received'.tr()
              : 'payment_marked_as_sent'.tr(),
          body: withProof
              ? 'payment_received_body'.tr(
                  namedArgs: {
                    'payer': payer,
                    'amount': amount,
                    'store': store,
                    'method_suffix': '',
                  },
                )
              : 'payment_marked_as_sent_body'.tr(
                  namedArgs: {'payer': payer, 'amount': amount},
                ),
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _sending = false;
      _proof = null;
      _lastStatus = GuestPayStatus.review;
    });
    final navigator = Navigator.of(context);
    await SuccessScreen.show<void>(
      context,
      title: 'guest_sent_title'.tr(namedArgs: {'host': guestHostName(bill)}),
      message: 'guest_sent_message'.tr(
        namedArgs: {'host': guestHostName(bill)},
      ),
      amountMinor: dueMinor,
      currency: bill.currency,
      primaryLabel: 'guest_done'.tr(),
      onPrimary: navigator.pop,
    );
  }

  Future<void> _messageHost(String phone) async {
    final uri = Uri(scheme: 'sms', path: phone);
    try {
      if (!await launchUrl(uri)) throw StateError('sms');
    } on Object {
      if (mounted) {
        AppToast.show(
          context,
          message: 'feedback_error_message'.tr(),
          type: AppToastType.error,
        );
      }
    }
  }

  // -------------------------------------------------------------- view

  _GuestView get _view {
    if (_loading) return _GuestView.loading;
    if (_notFound) return _GuestView.notFound;
    final bill = _bill;
    if (bill == null) return _failed ? _GuestView.error : _GuestView.loading;
    final now = (widget.clock ?? DateTime.now)();
    final me = bill.participant(_selectedId);
    if (me == null) {
      if (bill.isExpired(now)) return _GuestView.expired;
      if (bill.isSettled) return _GuestView.settled;
      return _GuestView.picker;
    }
    switch (me.status) {
      case GuestPayStatus.paid:
        return _GuestView.confirmed;
      case GuestPayStatus.review:
        return _GuestView.waiting;
      case GuestPayStatus.pending:
        if (bill.isExpired(now)) return _GuestView.expired;
        return _GuestView.share;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Wide screens: the canvas sits around a centred 480px card.
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final view = _view;
              final page = Column(
                children: [
                  _header(),
                  Expanded(child: _switcher(view, _body(view))),
                ],
              );
              if (constraints.maxWidth < 600) return page;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.background,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: p.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: page,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _switcher(_GuestView view, Widget child) => AnimatedSwitcher(
    duration: AppMotion.durationFor(context, AppMotion.medium),
    switchInCurve: AppMotion.quiet,
    switchOutCurve: AppMotion.quiet,
    // Fill the space so views lay out top-down instead of centered.
    layoutBuilder: (current, previous) =>
        Stack(fit: StackFit.expand, children: [...previous, ?current]),
    child: KeyedSubtree(key: ValueKey(view), child: child),
  );

  Widget _header() => const Padding(
    padding: EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
    child: Row(
      children: [
        GuestBrand(),
        Spacer(),
        Flexible(child: GuestLanguageButton()),
        SizedBox(width: 8),
        Flexible(child: GuestGetAppPill()),
      ],
    ),
  );

  Widget _body(_GuestView view) {
    final bill = _bill;
    final me = bill?.participant(_selectedId);
    switch (view) {
      case _GuestView.loading:
        return GuestLoadingSkeleton(
          personal: widget.initialParticipantId != null,
        );
      case _GuestView.error:
        return _errorView();
      case _GuestView.notFound:
        return _notFoundView();
      case _GuestView.expired:
        return _expiredView(bill!);
      case _GuestView.settled:
        return _settledView(bill!);
      case _GuestView.picker:
        return GuestSelectorView(bill: bill!, onParticipantSelected: _select);
      case _GuestView.share:
      case _GuestView.waiting:
      case _GuestView.confirmed:
        return _page(bill!, me!);
    }
  }

  Widget _bottomAction(Widget child) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 24),
    child: child,
  );

  Widget _notMeLink(GuestParticipant me) {
    final p = context.palette;
    final name = me.name.isEmpty ? 'guest'.tr() : me.name;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: p.textSecondary,
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: AppTypography.labelLarge.copyWith(
            fontSize: 13,
            decoration: TextDecoration.underline,
          ),
        ),
        onPressed: _notMe,
        child: Text('guest_not_you'.tr(namedArgs: {'name': name})),
      ),
    );
  }

  /// The single page: host line, chips, share card, then pay (pending) or
  /// the status note (sent / paid).
  Widget _page(GuestBill bill, GuestParticipant me) {
    final p = context.palette;
    final pending = me.status == GuestPayStatus.pending;
    final host = guestHostName(bill);
    final due = bill.dueMinorFor(me.id);
    final fromLink = widget.initialParticipantId != null && !_declinedLink;
    final waiting = me.status == GuestPayStatus.review;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GuestHostLine(bill: bill),
                const SizedBox(height: 16),
                if (!fromLink && bill.guests.length > 1) ...[
                  GuestChips(bill: bill, selectedId: me.id, onSelect: _select),
                  const SizedBox(height: 16),
                ],
                GuestShareCard(bill: bill, me: me),
                if (fromLink) _notMeLink(me),
                if (bill.items.isNotEmpty)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: p.primary,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: AppTypography.labelLarge.copyWith(
                          fontSize: 14,
                        ),
                      ),
                      onPressed: () => showGuestReceipt(context, bill),
                      child: Text('guest2_see_bill'.tr()),
                    ),
                  ),
                const SizedBox(height: 12),
                if (pending) ...[
                  GuestPayMethods(
                    bill: bill,
                    options: guestPayOptions(bill, due),
                    launcher: widget.launcher,
                  ),
                  const SizedBox(height: 14),
                  GuestProofZone(
                    bill: bill,
                    proof: _proof,
                    onPick: _pickProof,
                    onRemove: () => setState(() => _proof = null),
                  ),
                ] else ...[
                  GuestStatusNote(
                    confirmed: !waiting,
                    title: waiting
                        ? 'guest_waiting_title'.tr(namedArgs: {'host': host})
                        : 'guest_confirmed_title'.tr(
                            namedArgs: {
                              'host': host,
                              'amount': guestAmount(
                                bill.breakdownFor(me.id).totalMinor,
                                bill.currency,
                              ),
                            },
                          ),
                    message: waiting
                        ? 'guest_waiting_message'.tr(
                            namedArgs: {
                              'host': host,
                              'amount': guestAmount(due, bill.currency),
                            },
                          )
                        : 'guest_confirmed_message'.tr(
                            namedArgs: {'store': guestStoreName(bill)},
                          ),
                  ),
                  const SizedBox(height: 16),
                  const GuestGetAppCard(),
                ],
              ],
            ),
          ),
        ),
        if (pending)
          _bottomAction(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GuestPaidButton(
                  amount: guestAmount(due, bill.currency),
                  sending: _sending,
                  onPressed: () => _submit(bill, me),
                ),
                const SizedBox(height: 8),
                Text(
                  'guest2_paid_helper'.tr(namedArgs: {'host': host}),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _settledView(GuestBill bill) {
    final host = guestHostName(bill);
    final phone = bill.hostPhone;
    return GuestMessageView(
      title: 'guest_settled_title'.tr(),
      message: 'guest_settled_message'.tr(
        namedArgs: {'store': guestStoreName(bill), 'host': host},
      ),
      actionLabel: phone == null
          ? null
          : 'guest_message_host'.tr(namedArgs: {'host': host}),
      onAction: phone == null ? null : () => _messageHost(phone),
    );
  }

  Widget _expiredView(GuestBill bill) {
    final host = guestHostName(bill);
    final phone = bill.hostPhone;
    return GuestMessageView(
      title: 'guest_expired_title'.tr(),
      message: 'guest_expired_message'.tr(
        namedArgs: {'store': guestStoreName(bill), 'host': host},
      ),
      actionLabel: phone == null
          ? null
          : 'guest_message_host'.tr(namedArgs: {'host': host}),
      onAction: phone == null ? null : () => _messageHost(phone),
    );
  }

  Widget _notFoundView() => GuestMessageView(
    title: 'guest_not_found_title'.tr(),
    message: 'guest_not_found_message'.tr(),
    footer: const GuestGetAppCard(),
  );

  Widget _errorView() => ErrorState(
    icon: AppIcons.cloudOff,
    title: 'guest_load_error_title'.tr(),
    message: 'guest_load_error_message'.tr(),
    onRetry: () => setState(_subscribe),
  );
}
