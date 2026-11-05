import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/screens/edit_bill/edit_bill_controller.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/money_text.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

/// Add or edit one item: name, unit price and quantity (with a live line
/// total). Editing also offers "Remove item".
class EditItemSheet extends StatefulWidget {
  const EditItemSheet({
    super.key,
    required this.currency,
    required this.onSave,
    this.initial,
    this.onRemove,
  });

  final String currency;
  final DraftItem? initial;
  final ValueChanged<DraftItem> onSave;
  final VoidCallback? onRemove;

  static Future<void> show(
    BuildContext context, {
    required String currency,
    required ValueChanged<DraftItem> onSave,
    DraftItem? initial,
    VoidCallback? onRemove,
  }) => PremiumBottomSheet.show<void>(
    context: context,
    isScrollable: true,
    child: EditItemSheet(
      currency: currency,
      initial: initial,
      onSave: onSave,
      onRemove: onRemove,
    ),
  );

  @override
  State<EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<EditItemSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: moneyInputText(widget.initial?.unitPriceMinor ?? 0, widget.currency),
  );
  late int _qty = widget.initial?.quantity ?? 1;
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  int? get _priceMinor => parseMoneyInput(_price.text, widget.currency);

  void _save() {
    setState(() => _submitted = true);
    final price = _priceMinor;
    if (_name.text.trim().isEmpty || price == null || price <= 0) {
      AppHaptics.error();
      return;
    }
    AppHaptics.success();
    widget.onSave(
      DraftItem(name: _name.text.trim(), unitPriceMinor: price, quantity: _qty),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final price = _priceMinor;
    final nameError = _submitted && _name.text.trim().isEmpty
        ? 'bf_edit_item_name_needed'.tr()
        : null;
    final priceError =
        (_submitted && (price == null || price <= 0)) ||
            (price == null && _price.text.isNotEmpty)
        ? 'bf_edit_item_price_needed'.tr()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          (widget.initial == null ? 'bf_edit_add_item' : 'bf_edit_edit_item')
              .tr(),
          style: AppTypography.headlineSmall.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _name,
          autofocus: widget.initial == null,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'bf_edit_item_name'.tr(),
            errorText: nameError,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                style: AppTypography.amount.copyWith(color: p.textPrimary),
                decoration: InputDecoration(
                  labelText: 'bf_edit_item_unit_price'.tr(),
                  suffixText: widget.currency,
                  errorText: priceError,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            _QtyStepper(
              value: _qty,
              onChanged: (v) {
                AppHaptics.selection();
                setState(() => _qty = v);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'bf_edit_item_line_total'.tr(),
                style: AppTypography.bodyMedium.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
            MoneyText(
              minor: (price ?? 0) * _qty,
              currency: widget.currency,
              tone: MoneyTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: _save, child: Text('bf_edit_item_save'.tr())),
        if (widget.onRemove != null) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () {
              AppHaptics.warning();
              Navigator.of(context).pop();
              widget.onRemove!();
            },
            style: TextButton.styleFrom(foregroundColor: p.textSecondary),
            child: Text('bf_edit_item_remove'.tr()),
          ),
        ],
      ],
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.rowRadius,
        border: Border.all(color: p.borderStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            tooltip: 'bf_edit_qty_less'.tr(),
            icon: const Icon(Icons.remove_rounded),
          ),
          Semantics(
            label: 'bf_edit_qty_label'.tr(namedArgs: {'qty': '$value'}),
            excludeSemantics: true,
            child: SizedBox(
              width: 28,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: AppTypography.amount.copyWith(color: p.textPrimary),
              ),
            ),
          ),
          IconButton(
            onPressed: value < 999 ? () => onChanged(value + 1) : null,
            tooltip: 'bf_edit_qty_more'.tr(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
