import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

import '../guest_bill_model.dart';
import '../guest_bill_repository.dart';
import '../guest_platform.dart';
import 'guest_breakdown.dart';
import 'guest_chrome.dart';
import 'guest_qr.dart' deferred as guest_qr;

/// One of the host's methods, ready to tap.
class GuestPayOption {
  const GuestPayOption({
    required this.method,
    required this.launch,
    required this.request,
    this.qrPayload,
  });

  final StoredPaymentMethod method;
  final PaymentLaunch launch;
  final PaymentRequest request;
  final String? qrPayload;

  bool get opens => launch is DeepLinkLaunch;

  bool get prefills =>
      launch is DeepLinkLaunch && (launch as DeepLinkLaunch).prefillsAmount;
}

/// The host's methods for paying [amountMinor], filtered for this browser:
/// Apple Cash only in iOS Safari; app-only links (UPI) fall back to copying
/// the handle on the web (their QR still works).
List<GuestPayOption> guestPayOptions(
  GuestBill bill,
  int amountMinor, {
  bool web = kIsWeb,
  bool? iosSafari,
}) {
  final safari = iosSafari ?? isIosSafari;
  final options = <GuestPayOption>[];
  for (final method in parseBillPaymentMethods(bill.paymentMethods)) {
    final type = method.type;
    if (type.id == 'apple_cash' &&
        !(web ? safari : type.isAvailableOn(currentPaymentPlatform()))) {
      continue;
    }
    final request = PaymentRequest(
      handle: method.value,
      amount: amountMinor > 0 ? Money(amountMinor, bill.currency) : null,
      note: bill.storeName.isEmpty ? null : bill.storeName,
      recipientName: bill.hostName.isEmpty ? null : bill.hostName,
    );
    var launch = type.buildLaunch(request);
    final appOnly =
        web &&
        type.id != 'apple_cash' &&
        !type.isAvailableOn(PaymentPlatform.web);
    if (appOnly && launch is DeepLinkLaunch) {
      launch = CopyInstruction(
        text: method.handle,
        instructionKey: 'payment_instruction_copy_handle',
        instructionArgs: {
          'app': type.displayName,
          'amount': request.displayAmount,
          'handle': method.handle,
        },
      );
    }
    options.add(
      GuestPayOption(
        method: method,
        launch: launch,
        request: request,
        qrPayload: type.qrPayload(request),
      ),
    );
  }
  return options;
}

/// The list of method cards with Copy / Open / QR.
class GuestPayMethods extends StatefulWidget {
  const GuestPayMethods({
    super.key,
    required this.bill,
    required this.options,
    this.launcher = const PaymentLauncher(),
    this.compact = false,
  });

  final GuestBill bill;
  final List<GuestPayOption> options;
  final PaymentLauncher launcher;

  /// Desktop aside: rows without card chrome.
  final bool compact;

  @override
  State<GuestPayMethods> createState() => _GuestPayMethodsState();
}

class _GuestPayMethodsState extends State<GuestPayMethods> {
  int _selected = 0;
  int? _copied;
  int? _qrOpen;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _run(int index) async {
    final option = widget.options[index];
    setState(() => _selected = index);
    final outcome = await widget.launcher.run(option.launch);
    if (!mounted) return;
    final launch =
        option.launch is DeepLinkLaunch &&
            outcome == PaymentLaunchOutcome.copied
        ? (option.launch as DeepLinkLaunch).fallback
        : option.launch;
    final instruction = launch.instructionKey.tr(
      namedArgs: launch.instructionArgs,
    );
    switch (outcome) {
      case PaymentLaunchOutcome.failed:
        AppToast.show(
          context,
          message: 'could_not_launch_payment_app'.tr(),
          type: AppToastType.error,
        );
      case PaymentLaunchOutcome.copied:
        _copiedTimer?.cancel();
        setState(() => _copied = index);
        _copiedTimer = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _copied = null);
        });
        AppToast.show(
          context,
          message: instruction,
          type: AppToastType.success,
        );
      case PaymentLaunchOutcome.openedPrefilled:
      case PaymentLaunchOutcome.openedAmountCopied:
        AppToast.show(context, message: instruction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final options = widget.options;
    if (options.isEmpty) {
      return Text(
        'guest_no_methods'.tr(namedArgs: {'host': guestHostName(widget.bill)}),
        style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) SizedBox(height: widget.compact ? 12 : 8),
          _MethodRow(
            option: options[i],
            selected: !widget.compact && i == _selected,
            compact: widget.compact,
            copied: _copied == i,
            qrOpen: _qrOpen == i,
            onRun: () => _run(i),
            onToggleQr: options[i].qrPayload == null
                ? null
                : () => setState(() => _qrOpen = _qrOpen == i ? null : i),
          ),
        ],
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.option,
    required this.selected,
    required this.compact,
    required this.copied,
    required this.qrOpen,
    required this.onRun,
    required this.onToggleQr,
  });

  final GuestPayOption option;
  final bool selected;
  final bool compact;
  final bool copied;
  final bool qrOpen;
  final VoidCallback onRun;
  final VoidCallback? onToggleQr;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final method = option.method;
    final subtitle = option.prefills
        ? 'guest_opens_with'.tr(
            namedArgs: {
              'amount': guestAmount(
                option.request.amount!.minor,
                option.request.amount!.currency,
              ),
            },
          )
        : method.value;
    final ctaLabel = option.opens
        ? 'guest_open'.tr()
        : (copied ? 'guest_copied'.tr() : 'guest_copy'.tr());

    final ButtonStyle ctaStyle = compact
        ? OutlinedButton.styleFrom(
            minimumSize: const Size(64, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            side: BorderSide(color: p.borderStrong),
            backgroundColor: copied ? p.primary : p.surface,
            foregroundColor: copied ? p.onPrimary : p.textPrimary,
            textStyle: AppTypography.labelLarge.copyWith(fontSize: 14),
          )
        : FilledButton.styleFrom(
            minimumSize: const Size(64, 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: copied ? p.primary : p.inverseSurface,
            foregroundColor: copied ? p.onPrimary : p.onInverseSurface,
            textStyle: AppTypography.labelLarge.copyWith(fontSize: 13),
          );

    final cta = Semantics(
      label: '$ctaLabel ${method.label}',
      button: true,
      excludeSemantics: true,
      child: compact
          ? OutlinedButton(
              onPressed: onRun,
              style: ctaStyle,
              child: Text(ctaLabel),
            )
          : FilledButton(
              onPressed: onRun,
              style: ctaStyle,
              child: Text(ctaLabel),
            ),
    );

    final row = Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: compact ? 36 : 32,
            height: compact ? 36 : 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surfaceVariant,
              borderRadius: BorderRadius.circular(compact ? 9 : 8),
            ),
            child: Text(
              method.type.initials,
              style: AppTypography.labelSmall.copyWith(
                fontSize: compact ? 11 : 10,
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                method.label,
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 15,
                  color: p.textPrimary,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: option.prefills ? null : TextDirection.ltr,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: compact ? 14 : 13,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (onToggleQr != null) ...[
          IconButton(
            tooltip: qrOpen ? 'guest_hide_qr'.tr() : 'guest_show_qr'.tr(),
            onPressed: onToggleQr,
            icon: Icon(
              qrOpen ? Icons.close_rounded : Icons.qr_code_2_rounded,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
        ],
        cta,
      ],
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        AnimatedSize(
          duration: AppMotion.durationFor(context, AppMotion.medium),
          curve: AppMotion.standard,
          child: qrOpen && option.qrPayload != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _QrPanel(option: option),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );

    if (compact) return body;
    return GuestCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderColor: selected ? p.textPrimary : null,
      child: body,
    );
  }
}

class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.option});

  final GuestPayOption option;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Dark modules on a light square in both themes so every camera reads it.
    final background = p.isDark ? p.textPrimary : p.surface;
    final foreground = p.isDark ? p.background : p.textPrimary;
    final amount = option.request.displayAmount;
    return Column(
      children: [
        Semantics(
          image: true,
          label: 'guest_qr_semantics'.tr(
            namedArgs: {
              'amount': amount,
              'app': option.method.type.displayName,
            },
          ),
          child: ClipRRect(
            borderRadius: AppRadii.rowRadius,
            child: FutureBuilder<void>(
              future: guest_qr.loadLibrary(),
              builder: (context, snap) =>
                  snap.connectionState == ConnectionState.done
                  ? guest_qr.GuestQrCode(
                      data: option.qrPayload!,
                      foreground: foreground,
                      background: background,
                    )
                  : const Skeleton(width: 200, height: 200),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'payment_instruction_scan_qr'.tr(namedArgs: {'amount': amount}),
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
        ),
      ],
    );
  }
}

/// "Add a payment screenshot" dashed zone, or the chosen screenshot.
class GuestProofZone extends StatelessWidget {
  const GuestProofZone({
    super.key,
    required this.bill,
    required this.proof,
    required this.onPick,
    required this.onRemove,
    this.desktop = false,
  });

  final GuestBill bill;
  final GuestProof? proof;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final host = guestHostName(bill);
    final chosen = proof;
    if (chosen != null) {
      return GuestCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadii.rowRadius,
              child: Image.memory(
                chosen.bytes,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                semanticLabel: 'guest_screenshot_added'.tr(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'guest_screenshot_added'.tr(),
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 15,
                  color: p.textPrimary,
                ),
              ),
            ),
            TextButton(onPressed: onPick, child: Text('guest_change'.tr())),
            IconButton(
              tooltip: 'guest_remove_screenshot'.tr(),
              onPressed: onRemove,
              icon: Icon(Icons.close_rounded, color: p.textSecondary),
            ),
          ],
        ),
      );
    }
    final title = desktop
        ? 'guest_choose_screenshot'.tr()
        : 'guest_add_screenshot'.tr();
    final hint = desktop
        ? 'guest_choose_screenshot_hint'.tr()
        : 'guest_add_screenshot_hint'.tr(namedArgs: {'host': host});
    return Semantics(
      button: true,
      label: '$title. $hint',
      excludeSemantics: true,
      child: GuestDashedBorder(
        radius: desktop ? 14 : 20,
        child: Material(
          color: desktop ? Colors.transparent : p.surface,
          borderRadius: BorderRadius.circular(desktop ? 14 : 20),
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(desktop ? 14 : 20),
            child: Padding(
              padding: EdgeInsets.all(desktop ? 18 : 16),
              child: Column(
                children: [
                  if (!desktop) ...[
                    Icon(
                      Icons.file_upload_outlined,
                      size: 26,
                      color: p.textSecondary,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleSmall.copyWith(
                      fontSize: 15,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 13,
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "I've paid" pill; shows progress while sending.
class GuestPaidButton extends StatelessWidget {
  const GuestPaidButton({
    super.key,
    required this.sending,
    required this.onPressed,
  });

  final bool sending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 54)),
        onPressed: sending ? null : onPressed,
        child: sending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('guest_sending'.tr()),
                ],
              )
            : Text('i_ve_paid'.tr()),
      ),
    );
  }
}
