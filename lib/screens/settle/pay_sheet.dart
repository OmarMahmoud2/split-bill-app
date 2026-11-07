/// "You pay Mona": the recipient's saved methods, opened with the amount
/// filled in where the app supports it (payments registry + launcher).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Payment launcher used by the sheet; tests replace it.
PaymentLauncher paymentLauncher = const PaymentLauncher();

/// What the payer chose: record the payment with [method] (a registry id,
/// or `cash`).
class PaySheetResult {
  const PaySheetResult(this.method);
  final String method;
}

Future<PaySheetResult?> showPaySheet(
  BuildContext context, {
  required String recipientId,
  required String recipientName,
  required int amountMinor,
  required String currency,
  String? contextLabel,
  String? note,
  bool recipientHasAccount = true,
}) => showLedgerSheet<PaySheetResult>(
  context,
  builder: (_) => PaySheet(
    recipientId: recipientId,
    recipientName: recipientName,
    amountMinor: amountMinor,
    currency: currency,
    contextLabel: contextLabel,
    note: note,
    recipientHasAccount: recipientHasAccount,
  ),
);

class PaySheet extends StatefulWidget {
  const PaySheet({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.amountMinor,
    required this.currency,
    this.contextLabel,
    this.note,
    this.recipientHasAccount = true,
  });

  final String recipientId;
  final String recipientName;
  final int amountMinor;
  final String currency;
  final String? contextLabel;
  final String? note;
  final bool recipientHasAccount;

  @override
  State<PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<PaySheet> {
  late Future<List<StoredPaymentMethod>> _methods = _load();
  StoredPaymentMethod? _selected;
  bool _launched = false;

  Future<List<StoredPaymentMethod>> _load() async {
    if (!widget.recipientHasAccount) return const [];
    final profile = await LedgerRepository.instance.publicProfile(widget.recipientId);
    final platform = currentPaymentPlatform();
    final methods = parseStoredPaymentMethods(profile)
        .where((m) => m.value.trim().isNotEmpty && m.type.isAvailableOn(platform))
        .toList();
    if (methods.isNotEmpty && mounted) setState(() => _selected ??= methods.first);
    return methods;
  }

  Future<void> _open(StoredPaymentMethod m) async {
    AppHaptics.light();
    final launch = m.launch(
      (handle) => localizedPaymentRequest(
        handle: handle,
        amount: Money(widget.amountMinor, normalizeCurrency(widget.currency)),
        note: widget.note ?? widget.contextLabel,
        recipientName: widget.recipientName,
      ),
    );
    final outcome = await paymentLauncher.run(launch);
    if (!mounted) return;
    final instruction = launch.instructionKey.tr(namedArgs: launch.instructionArgs);
    switch (outcome) {
      case PaymentLaunchOutcome.openedPrefilled:
      case PaymentLaunchOutcome.openedAmountCopied:
      case PaymentLaunchOutcome.copied:
        AppToast.show(context, message: instruction, type: AppToastType.info, position: AppToastPosition.top);
        setState(() => _launched = true);
      case PaymentLaunchOutcome.failed:
        AppToast.show(
          context,
          message: 'pay_open_failed'.tr(namedArgs: {'app': m.label}),
          type: AppToastType.error,
          position: AppToastPosition.top,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final amount = moneyLabel(context, widget.amountMinor, widget.currency);
    final who = widget.contextLabel == null || widget.contextLabel!.isEmpty
        ? 'pay_you_pay'.tr(namedArgs: {'name': widget.recipientName})
        : 'pay_you_pay_in'.tr(namedArgs: {'name': widget.recipientName, 'group': widget.contextLabel!});
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(who, style: AppTypography.bodyMedium.copyWith(color: p.textSecondary)),
          const SizedBox(height: 2),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MoneyText(
              minor: widget.amountMinor,
              currency: widget.currency,
              tone: MoneyTone.neutral,
              size: MoneySize.large,
              style: const TextStyle(fontSize: 40),
            ),
          ),
          FutureBuilder<List<StoredPaymentMethod>>(
            future: _methods,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: SkeletonShimmer(child: SkeletonCard()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ErrorState.inline(
                    title: 'pay_methods_failed_title'.tr(),
                    message: 'pay_methods_failed_body'.tr(),
                    onRetry: () => setState(() => _methods = _load()),
                    secondaryLabel: 'settle_record_cash'.tr(),
                    onSecondary: () => Navigator.of(context).pop(const PaySheetResult('cash')),
                  ),
                );
              }
              final methods = snap.data!;
              if (methods.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LedgerCard(
                        child: EmptyState(
                          compact: true,
                          icon: AppIcons.wallet,
                          title: 'pay_no_methods_title'.tr(namedArgs: {'name': widget.recipientName}),
                          message: 'pay_no_methods_body'.tr(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(const PaySheetResult('cash')),
                        child: Text('settle_record_cash'.tr()),
                      ),
                    ],
                  ),
                );
              }
              final selected = _selected ?? methods.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OverlineLabel(
                    'pay_accepts'.tr(namedArgs: {'name': widget.recipientName}),
                    padding: const EdgeInsets.only(top: 14, bottom: 8),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.9,
                    children: [
                      for (final m in methods)
                        _MethodTile(
                          method: m,
                          selected: identical(m, selected),
                          onTap: () {
                            AppHaptics.selection();
                            setState(() {
                              _selected = m;
                              _launched = false;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'pay_footnote'.tr(),
                    style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (!_launched)
                    FilledButton(
                      onPressed: () => _open(selected),
                      child: Text('pay_open_app'.tr(namedArgs: {'app': selected.label, 'amount': amount})),
                    )
                  else ...[
                    Text(
                      'pay_did_it_go_through'.tr(),
                      textAlign: TextAlign.center,
                      style: AppTypography.titleSmall.copyWith(color: p.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(PaySheetResult(selected.type.id)),
                      child: Text('pay_yes_mark_paid'.tr()),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _open(selected),
                      child: Text('pay_open_again'.tr(namedArgs: {'app': selected.label})),
                    ),
                  ],
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(const PaySheetResult('cash')),
                    child: Text('pay_paid_in_cash'.tr()),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.method, required this.selected, required this.onTap});
  final StoredPaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final logo = method.type.logoAsset;
    return Semantics(
      selected: selected,
      button: true,
      label: '${method.label}, ${method.value}',
      child: LedgerCard(
        onTap: onTap,
        borderColor: selected ? p.textPrimary : p.border,
        borderWidth: selected ? 2 : AppRadii.hairline,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: ExcludeSemantics(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadii.chipRadius,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: logo != null
                      ? Image.asset(logo, fit: BoxFit.cover, errorBuilder: (_, _, _) => _initials(p))
                      : _initials(p),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(color: p.textPrimary, fontSize: 14),
                    ),
                    Text(
                      method.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: p.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _initials(AppPalette p) => ColoredBox(
    color: p.surfaceVariant,
    child: Center(
      child: Text(
        method.type.initials,
        style: AppTypography.labelSmall.copyWith(color: p.textPrimary, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
