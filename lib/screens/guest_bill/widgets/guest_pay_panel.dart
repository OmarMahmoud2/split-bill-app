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
    final request = localizedPaymentRequest(
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
    final index = _selected.clamp(0, options.length - 1);
    final selected = options[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'guest2_pay_with'.tr(
              namedArgs: {'host': guestHostName(widget.bill)},
            ),
            style: AppTypography.labelLarge.copyWith(
              fontSize: 13,
              color: p.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final cols = options.length >= 3 ? 3 : options.length;
            final w = (c.maxWidth - 8 * (cols - 1)) / cols;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < options.length; i++)
                  SizedBox(
                    width: w,
                    child: _MethodTile(
                      option: options[i],
                      selected: i == index,
                      copied: _copied == i,
                      onRun: () => _run(i),
                    ),
                  ),
              ],
            );
          },
        ),
        if (!selected.opens) ...[
          const SizedBox(height: 8),
          Text(
            selected.method.value,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              color: p.textSecondary,
            ),
          ),
        ],
        if (selected.qrPayload != null) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: p.textPrimary,
                minimumSize: const Size(44, 44),
              ),
              onPressed: () =>
                  setState(() => _qrOpen = _qrOpen == index ? null : index),
              icon: Icon(_qrOpen == index ? AppIcons.close : AppIcons.qr),
              label: Text(
                _qrOpen == index
                    ? 'guest_hide_qr'.tr()
                    : 'guest_show_qr'.tr(),
              ),
            ),
          ),
          if (_qrOpen == index)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _QrPanel(option: selected),
            ),
        ],
      ],
    );
  }
}

/// A "Pay Omar with" tile: name + "Copy" / "Open".
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.option,
    required this.selected,
    required this.copied,
    required this.onRun,
  });

  final GuestPayOption option;
  final bool selected;
  final bool copied;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final method = option.method;
    final ctaLabel = option.opens
        ? 'guest_open'.tr()
        : (copied ? 'guest_copied'.tr() : 'guest_copy'.tr());
    return Semantics(
      label: '$ctaLabel ${method.label}',
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: selected ? p.primarySoft : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: selected
              ? BorderSide(color: p.primary, width: 2)
              : BorderSide(color: p.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onRun,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    method.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ctaLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: copied ? p.primary : p.textSecondary,
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
              icon: Icon(AppIcons.close, color: p.textSecondary),
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
                      AppIcons.upload,
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
    this.amount,
  });

  final String? amount;
  final bool sending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
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
            : Text(
                amount == null
                    ? 'i_ve_paid'.tr()
                    : 'guest2_paid_amount'.tr(namedArgs: {'amount': amount!}),
              ),
      ),
    );
  }
}
