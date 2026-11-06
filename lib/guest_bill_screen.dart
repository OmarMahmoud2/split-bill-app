import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/money_text.dart';

import 'screens/guest_bill/guest_bill_model.dart';
import 'screens/guest_bill/guest_bill_repository.dart';
import 'screens/guest_bill/guest_selector_view.dart';
import 'screens/guest_bill/widgets/guest_breakdown.dart';
import 'screens/guest_bill/widgets/guest_chrome.dart';
import 'screens/guest_bill/widgets/guest_pay_panel.dart';
import 'screens/guest_bill/widgets/guest_status_views.dart';

/// Width at which the guest page switches to the two-column desktop layout.
const double guestDesktopBreakpoint = 900;

enum _GuestView {
  loading,
  error,
  notFound,
  expired,
  settled,
  picker,
  share,
  pay,
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
  bool _paying = false;
  GuestProof? _proof;
  bool _sending = false;
  GuestPayStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
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
      _paying = false;
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
    final bill = GuestBill.fromMap(widget.billId, data);
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
      if (status != GuestPayStatus.pending) _paying = false;
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
      _paying = false;
      _proof = null;
      _lastStatus = _bill?.participant(id)?.status;
    });
  }

  void _notMe() {
    setState(() {
      _selectedId = null;
      _declinedLink = true;
      _paying = false;
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
    final breakdown = bill.breakdownFor(me.id);
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

    final amount = guestAmount(breakdown.totalMinor, bill.currency);
    final payer = me.name.isEmpty ? 'guest'.tr() : me.name;
    final store = guestStoreName(bill);
    final withProof = proof != null;
    unawaited(
      _repo.notifyHost(
        GuestPaymentNotice(
          billId: bill.id,
          hostId: bill.hostId,
          payerName: payer,
          storeName: store,
          formattedAmount: amount,
          amount: fromMinorUnits(breakdown.totalMinor, bill.currency),
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
      _paying = false;
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
      amountMinor: breakdown.totalMinor,
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
        return _paying ? _GuestView.pay : _GuestView.share;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= guestDesktopBreakpoint;
            final view = _view;
            return desktop ? _desktop(view) : _phone(view);
          },
        ),
      ),
    );
  }

  Widget _switcher(_GuestView view, Widget child) => AnimatedSwitcher(
    duration: AppMotion.durationFor(context, AppMotion.slow),
    switchInCurve: AppMotion.quiet,
    switchOutCurve: AppMotion.quiet,
    // Fill the space so views lay out top-down instead of centered.
    layoutBuilder: (current, previous) =>
        Stack(fit: StackFit.expand, children: [...previous, ?current]),
    child: KeyedSubtree(key: ValueKey(view), child: child),
  );

  Widget _phone(_GuestView view) {
    final bill = _bill;
    final me = bill?.participant(_selectedId);
    final Widget header;
    if (view == _GuestView.pay && bill != null && me != null) {
      final total = bill.breakdownFor(me.id).totalMinor;
      header = Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 20, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: 'back'.tr(),
              onPressed: () => setState(() => _paying = false),
              icon: const BackButtonIcon(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'guest_pay_host_amount'.tr(
                    namedArgs: {
                      'host': guestHostName(bill),
                      'amount': guestAmount(total, bill.currency),
                    },
                  ),
                  style: AppTypography.headlineMedium.copyWith(
                    fontSize: 18,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      header = const Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [GuestBrand(), GuestLanguageButton()],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            header,
            Expanded(child: _switcher(view, _phoneBody(view))),
          ],
        ),
      ),
    );
  }

  Widget _phoneBody(_GuestView view) {
    final bill = _bill;
    final me = bill?.participant(_selectedId);
    switch (view) {
      case _GuestView.loading:
        return const GuestLoadingSkeleton();
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
        return _phoneShare(bill!, me!);
      case _GuestView.pay:
        return _phonePay(bill!, me!);
      case _GuestView.waiting:
        return _waitingView(bill!, me!);
      case _GuestView.confirmed:
        return _confirmedView(bill!, me!);
    }
  }

  Widget _bottomAction(Widget child) =>
      Padding(padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 30), child: child);

  Widget _notMeLink(GuestParticipant me) {
    final p = context.palette;
    final name = me.name.isEmpty ? 'guest'.tr() : me.name;
    return TextButton(
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
    );
  }

  Widget _phoneShare(GuestBill bill, GuestParticipant me) {
    final p = context.palette;
    final breakdown = bill.breakdownFor(me.id);
    final name = me.name.isEmpty ? 'guest'.tr() : me.name;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'guest_hi_share_of'.tr(
                    namedArgs: {'name': name, 'store': guestStoreName(bill)},
                  ),
                  style: AppTypography.bodyLarge.copyWith(
                    fontSize: 15,
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                // Amounts read left to right in every locale (v3 RTL mock).
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: MoneyText(
                        minor: breakdown.totalMinor,
                        currency: breakdown.currency,
                        tone: MoneyTone.neutral,
                        size: MoneySize.hero,
                        style: const TextStyle(fontSize: 52),
                      ),
                    ),
                  ),
                ),
                _notMeLink(me),
                const SizedBox(height: 6),
                GuestBreakdownCard(bill: bill, breakdown: breakdown),
              ],
            ),
          ),
        ),
        _bottomAction(
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 54)),
              onPressed: () => setState(() => _paying = true),
              child: Text(
                'guest_pay_host'.tr(namedArgs: {'host': guestHostName(bill)}),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _phonePay(GuestBill bill, GuestParticipant me) {
    final total = bill.breakdownFor(me.id).totalMinor;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GuestPayMethods(
                  bill: bill,
                  options: guestPayOptions(bill, total),
                  launcher: widget.launcher,
                ),
                const SizedBox(height: 14),
                GuestProofZone(
                  bill: bill,
                  proof: _proof,
                  onPick: _pickProof,
                  onRemove: () => setState(() => _proof = null),
                ),
              ],
            ),
          ),
        ),
        _bottomAction(
          GuestPaidButton(
            sending: _sending,
            onPressed: () => _submit(bill, me),
          ),
        ),
      ],
    );
  }

  Widget _waitingView(GuestBill bill, GuestParticipant me) {
    final host = guestHostName(bill);
    return GuestOutcomeView(
      confirmed: false,
      title: 'guest_waiting_title'.tr(namedArgs: {'host': host}),
      message: 'guest_waiting_message'.tr(
        namedArgs: {
          'host': host,
          'amount': guestAmount(
            bill.breakdownFor(me.id).totalMinor,
            bill.currency,
          ),
        },
      ),
      footer: const GuestGetAppCard(),
    );
  }

  Widget _confirmedView(GuestBill bill, GuestParticipant me) {
    return GuestOutcomeView(
      confirmed: true,
      title: 'guest_confirmed_title'.tr(
        namedArgs: {
          'host': guestHostName(bill),
          'amount': guestAmount(
            bill.breakdownFor(me.id).totalMinor,
            bill.currency,
          ),
        },
      ),
      message: 'guest_confirmed_message'.tr(
        namedArgs: {'store': guestStoreName(bill)},
      ),
      footer: const GuestGetAppCard(),
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
    icon: Icons.cloud_off_rounded,
    title: 'guest_load_error_title'.tr(),
    message: 'guest_load_error_message'.tr(),
    onRetry: () => setState(_subscribe),
  );

  // ----------------------------------------------------------- desktop

  Widget _desktop(_GuestView view) {
    final p = context.palette;
    final twoColumn = view == _GuestView.share || view == _GuestView.pay;
    final header = DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                GuestBrand(large: true),
                Spacer(),
                GuestLanguageButton(),
                SizedBox(width: 10),
                GuestGetAppPill(),
              ],
            ),
          ),
        ),
      ),
    );

    final Widget body;
    if (twoColumn) {
      body = SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: _desktopShare(_bill!, _bill!.participant(_selectedId)!),
            ),
          ),
        ),
      );
    } else {
      final inner = switch (view) {
        _GuestView.waiting || _GuestView.confirmed => Padding(
          padding: const EdgeInsets.only(top: 24),
          child: _phoneBody(view),
        ),
        _ => _phoneBody(view),
      };
      body = Align(
        alignment: view == _GuestView.picker || view == _GuestView.loading
            ? Alignment.topCenter
            : Alignment.center,
        child: Padding(
          padding: EdgeInsets.only(
            top: view == _GuestView.picker || view == _GuestView.loading
                ? 24
                : 0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: inner,
          ),
        ),
      );
    }

    return Column(
      children: [
        header,
        Expanded(child: _switcher(view, body)),
      ],
    );
  }

  Widget _desktopShare(GuestBill bill, GuestParticipant me) {
    final p = context.palette;
    final breakdown = bill.breakdownFor(me.id);
    final host = guestHostName(bill);
    final store = guestStoreName(bill);
    final name = me.name.isEmpty ? 'guest'.tr() : me.name;
    final shared = bill.date == null
        ? 'guest_shared_store'.tr(namedArgs: {'host': host, 'store': store})
        : 'guest_shared_store_on'.tr(
            namedArgs: {
              'host': host,
              'store': store,
              'date': MaterialLocalizations.of(
                context,
              ).formatShortMonthDay(bill.date!),
            },
          );

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shared,
          style: AppTypography.bodyLarge.copyWith(
            fontSize: 16,
            color: p.textSecondary,
          ),
        ),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(
            'guest_hi_share_is'.tr(
              namedArgs: {
                'name': name,
                'amount': guestAmount(breakdown.totalMinor, bill.currency),
              },
            ),
            style: AppTypography.displayLarge.copyWith(color: p.textPrimary),
          ),
        ),
        _notMeLink(me),
        const SizedBox(height: 8),
        GuestBreakdownTable(bill: bill, breakdown: breakdown),
        if (bill.items.isNotEmpty) ...[
          const SizedBox(height: 10),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: p.primary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              textStyle: AppTypography.labelLarge.copyWith(fontSize: 15),
            ),
            onPressed: () => showGuestReceipt(context, bill),
            child: Text('guest_see_receipt_who'.tr()),
          ),
        ],
      ],
    );

    final aside = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GuestCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'guest_pay_host'.tr(namedArgs: {'host': host}),
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 17,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GuestPayMethods(
                bill: bill,
                options: guestPayOptions(bill, breakdown.totalMinor),
                launcher: widget.launcher,
                compact: true,
              ),
              const SizedBox(height: 18),
              GuestProofZone(
                bill: bill,
                proof: _proof,
                desktop: true,
                onPick: _pickProof,
                onRemove: () => setState(() => _proof = null),
              ),
              const SizedBox(height: 12),
              GuestPaidButton(
                sending: _sending,
                onPressed: () => _submit(bill, me),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'guest_privacy_desktop'.tr(),
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              height: 1.5,
              color: p.textSecondary,
            ),
          ),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 28),
        SizedBox(width: 380, child: aside),
      ],
    );
  }
}
