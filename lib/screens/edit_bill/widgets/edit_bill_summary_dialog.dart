import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/screens/edit_bill/edit_bill_controller.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';

/// Confirmed charges, all in minor units of the bill currency.
typedef ChargesConfirm =
    void Function({
      required int taxMinor,
      required int serviceMinor,
      required int tipMinor,
      required int deliveryMinor,
      required int discountMinor,
    });

/// Tax, service, tip, delivery and discount editor (a bottom sheet).
///
/// Amounts are typed in the bill currency; each field shows what it is as a
/// share of the items subtotal. A discount larger than the bill is caught
/// here with a clear message instead of producing negative shares.
class EditBillSummaryDialog extends StatefulWidget {
  const EditBillSummaryDialog({
    super.key,
    required this.currency,
    required this.subtotalMinor,
    required this.taxMinor,
    required this.serviceMinor,
    required this.tipMinor,
    required this.deliveryMinor,
    required this.discountMinor,
    required this.onConfirm,
  });

  final String currency;
  final int subtotalMinor;
  final int taxMinor;
  final int serviceMinor;
  final int tipMinor;
  final int deliveryMinor;
  final int discountMinor;
  final ChargesConfirm onConfirm;

  static Future<void> show(
    BuildContext context, {
    required String currency,
    required int subtotalMinor,
    required int taxMinor,
    required int serviceMinor,
    required int tipMinor,
    required int deliveryMinor,
    required int discountMinor,
    required ChargesConfirm onConfirm,
  }) => showLedgerSheet<void>(
    context,
    builder: (_) => SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
      child: EditBillSummaryDialog(
        currency: currency,
        subtotalMinor: subtotalMinor,
        taxMinor: taxMinor,
        serviceMinor: serviceMinor,
        tipMinor: tipMinor,
        deliveryMinor: deliveryMinor,
        discountMinor: discountMinor,
        onConfirm: onConfirm,
      ),
    ),
  );

  @override
  State<EditBillSummaryDialog> createState() => _EditBillSummaryDialogState();
}

enum _Charge { tax, service, tip, delivery, discount }

class _EditBillSummaryDialogState extends State<EditBillSummaryDialog> {
  late final Map<_Charge, TextEditingController> _controllers = {
    _Charge.tax: _c(widget.taxMinor),
    _Charge.service: _c(widget.serviceMinor),
    _Charge.tip: _c(widget.tipMinor),
    _Charge.delivery: _c(widget.deliveryMinor),
    _Charge.discount: _c(widget.discountMinor),
  };

  TextEditingController _c(int minor) =>
      TextEditingController(text: moneyInputText(minor, widget.currency));

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int? _value(_Charge c) =>
      parseMoneyInput(_controllers[c]!.text, widget.currency);

  String _label(_Charge c) => switch (c) {
    _Charge.tax => 'bf_edit_charge_tax',
    _Charge.service => 'bf_edit_charge_service',
    _Charge.tip => 'bf_edit_charge_tip',
    _Charge.delivery => 'bf_edit_charge_delivery',
    _Charge.discount => 'bf_edit_charge_discount',
  }.tr();

  int get _beforeDiscount =>
      widget.subtotalMinor +
      (_value(_Charge.tax) ?? 0) +
      (_value(_Charge.service) ?? 0) +
      (_value(_Charge.tip) ?? 0) +
      (_value(_Charge.delivery) ?? 0);

  bool get _discountTooLarge =>
      (_value(_Charge.discount) ?? 0) > _beforeDiscount;

  bool get _valid =>
      _Charge.values.every((c) => _value(c) != null) && !_discountTooLarge;

  void _save() {
    if (!_valid) {
      AppHaptics.error();
      setState(() {});
      return;
    }
    AppHaptics.success();
    widget.onConfirm(
      taxMinor: _value(_Charge.tax)!,
      serviceMinor: _value(_Charge.service)!,
      tipMinor: _value(_Charge.tip)!,
      deliveryMinor: _value(_Charge.delivery)!,
      discountMinor: _value(_Charge.discount)!,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'bf_edit_charges_title'.tr(),
          style: AppTypography.headlineSmall.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'bf_edit_charges_hint'.tr(
            namedArgs: {
              'amount': formatMoneyMinor(widget.subtotalMinor, widget.currency),
            },
          ),
          style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final c in _Charge.values) ...[
          _field(c),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: _save,
          child: Text('bf_edit_charges_apply'.tr()),
        ),
      ],
    );
  }

  Widget _field(_Charge c) {
    final p = context.palette;
    final value = _value(c);
    String? error;
    if (value == null) {
      error = 'bf_edit_amount_invalid'.tr();
    } else if (c == _Charge.discount && _discountTooLarge) {
      error = 'bf_edit_issue_discount'.tr(
        namedArgs: {
          'amount': formatMoneyMinor(_beforeDiscount, widget.currency),
        },
      );
    }
    final pct = value == null || value == 0
        ? null
        : chargePercentLabel(
            value,
            widget.subtotalMinor,
            widget.currency,
            serviceMinor: c == _Charge.tax ? (_value(_Charge.service) ?? 0) : 0,
          );
    return TextField(
      controller: _controllers[c],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      style: AppTypography.amount.copyWith(color: p.textPrimary),
      decoration: InputDecoration(
        labelText: _label(c),
        hintText: formatMoneyMinor(0, widget.currency, showSymbol: false),
        suffixText: widget.currency,
        helperText: pct == null
            ? null
            : 'bf_edit_charge_of_subtotal'.tr(namedArgs: {'percent': pct}),
        errorText: error,
        errorMaxLines: 3,
      ),
    );
  }
}
