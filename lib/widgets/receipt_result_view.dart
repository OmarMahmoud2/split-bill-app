import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/domain/money.dart' show currencyDecimals;
import 'package:split_bill_app/screens/scan_receipt/amount_input.dart';
import 'package:split_bill_app/screens/scan_receipt/review_banner_content.dart';
import 'package:split_bill_app/screens/scan_receipt/review_totals.dart';
import 'package:split_bill_app/screens/scan_receipt/widgets/participants_reference_list.dart';
import 'package:split_bill_app/screens/scan_receipt/widgets/review_banner.dart';
import 'package:split_bill_app/screens/scan_receipt/widgets/scan_top_bar.dart';
import 'package:split_bill_app/widgets/app_text_field.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/money_text.dart';
import 'package:split_bill_app/utils/dispose_later.dart';

/// "Review, everything editable, nothing hidden": the scanned receipt with
/// its header (store, date, currency, item count), the review banner, the
/// items, and the charges card. All money is computed in minor units from
/// what is in the edit fields.
///
/// Edits go into the given controllers (through the dialogs here) and then
/// [onSave] lets the owner write them back into [receiptData].
class ReceiptResultView extends StatelessWidget {
  const ReceiptResultView({
    super.key,
    required this.receiptData,
    required this.itemControllers,
    required this.currencyCode,
    required this.restaurantController,
    required this.taxController,
    required this.serviceController,
    required this.discountController,
    required this.tipController,
    required this.deliveryController,
    required this.onSave,
    required this.onAddItem,
    required this.onUpdateItem,
    required this.onDeleteItem,
    required this.selectedDate,
    required this.onDateChanged,
    this.image,
    this.participants,
    this.headerTrailing = const [],
    this.bottom,
  });

  final Map<String, dynamic> receiptData;
  final List<Map<String, TextEditingController>> itemControllers;
  final String currencyCode;
  final TextEditingController restaurantController;
  final TextEditingController taxController;
  final TextEditingController serviceController;
  final TextEditingController discountController;
  final TextEditingController tipController;
  final TextEditingController deliveryController;
  final VoidCallback onSave;
  final void Function(String name, String qtyText, String priceText) onAddItem;
  final void Function(int index, String name, String qtyText, String priceText)
  onUpdateItem;
  final void Function(int index) onDeleteItem;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  /// The scanned photo, for "View photo".
  final File? image;
  final List<Map<String, dynamic>>? participants;
  final List<Widget> headerTrailing;

  /// Pinned under the list (the "Looks right · add people" button).
  final Widget? bottom;

  BillDraft _draft() => buildReviewDraft(
    receiptData: receiptData,
    currency: currencyCode,
    lines: [
      for (final c in itemControllers)
        (
          name: c['name']?.text ?? '',
          qty: c['qty']?.text ?? '1',
          price: c['price']?.text ?? '0',
        ),
    ],
    charges: (
      tax: taxController.text,
      service: serviceController.text,
      tip: tipController.text,
      delivery: deliveryController.text,
      discount: discountController.text,
    ),
  );

  List<Map<String, dynamic>> get _items => [
    for (final item in (receiptData['items'] as List? ?? const []))
      if (item is Map) Map<String, dynamic>.from(item),
  ];

  String _dateLabel() {
    try {
      return DateFormat.MMMd().format(selectedDate);
    } catch (_) {
      return '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft();
    final currency = draft.currency;
    final items = _items;
    final reasons = [
      for (final r
          in (receiptData['needs_review_reasons'] as List? ?? const []))
        r.toString(),
    ];
    final reconciliation = receiptData['reconciliation'];
    final banner = buildReviewBanner(
      items: items,
      currency: currency,
      currentTotalMinor: draft.grandTotalMinor,
      reasons: reasons,
      reconciliation: reconciliation is Map ? reconciliation : null,
      needsReview: receiptData['needs_review'] == true,
    );
    final flagged = banner?.flaggedItemIndexes ?? const <int>{};

    final storeName = restaurantController.text.trim().isNotEmpty
        ? restaurantController.text.trim()
        : 'receipt_store_name'.tr();
    final count = itemControllers.length;
    final countLabel = count == 1
        ? 'bf_scan_review_items_one'.tr()
        : 'bf_scan_review_items_other'.tr(namedArgs: {'count': '$count'});
    final subtitle = '${_dateLabel()} · $currency · $countLabel';

    return Column(
      children: [
        ScanTopBar(
          title: storeName,
          subtitle: subtitle,
          onTitleTap: () => _showDetailsDialog(context),
          titleTapLabel: 'bf_scan_review_edit_details'.tr(),
          trailing: [
            if (image != null)
              ScanRoundButton(
                icon: AppIcons.gallery,
                label: 'bf_scan_review_view_photo'.tr(),
                onPressed: () => _showPhoto(context),
              ),
            ...headerTrailing,
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 20),
            children: [
              if (banner != null) ...[
                ReviewBanner(content: banner),
                const SizedBox(height: AppSpacing.md),
              ],
              _ItemsCard(
                controllers: itemControllers,
                currency: currency,
                flagged: flagged,
                draft: draft,
                onTapItem: (i) => _showItemEditorDialog(context, index: i),
                onAddItem: () => _showItemEditorDialog(context),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildChargesCard(context, draft),
              ParticipantsReferenceList(participants: participants),
            ],
          ),
        ),
        ?bottom,
      ],
    );
  }

  // ------------------------------------------------------------- charges

  Widget _buildChargesCard(BuildContext context, BillDraft draft) {
    final p = context.palette;
    final currency = draft.currency;
    final subtotal = draft.itemsSubtotalMinor;
    final byWhatEachHad = 'bf_scan_review_by_what_each_had'.tr();

    String withPct(String label, int amount, [String? rate]) {
      final pct = rate ?? percentLabel(amount, subtotal);
      return pct == null
          ? '$label · $byWhatEachHad'
          : '$label $pct% · $byWhatEachHad';
    }

    final rows = <Widget>[
      _ChargeRow(
        label: 'receipt_subtotal'.tr(),
        minor: subtotal,
        currency: currency,
      ),
      if (draft.taxMinor > 0)
        _ChargeRow(
          label: withPct(
            'receipt_tax'.tr(),
            draft.taxMinor,
            taxPercentLabel(draft.taxMinor, subtotal, draft.serviceMinor),
          ),
          minor: draft.taxMinor,
          currency: currency,
          onTap: () =>
              _showAmountDialog(context, 'receipt_tax'.tr(), taxController),
        ),
      if (draft.serviceMinor > 0)
        _ChargeRow(
          label: withPct('receipt_service_charge'.tr(), draft.serviceMinor),
          minor: draft.serviceMinor,
          currency: currency,
          onTap: () => _showAmountDialog(
            context,
            'receipt_service_charge'.tr(),
            serviceController,
          ),
        ),
      if (draft.deliveryMinor > 0)
        _ChargeRow(
          label: 'receipt_delivery_fee'.tr(),
          minor: draft.deliveryMinor,
          currency: currency,
          onTap: () => _showAmountDialog(
            context,
            'receipt_delivery_fee'.tr(),
            deliveryController,
          ),
        ),
      for (final charge in draft.otherCharges)
        if (charge.amountMinor != 0)
          _ChargeRow(
            label: charge.label.isEmpty
                ? 'receipt_other_charges'.tr()
                : charge.label,
            minor: charge.amountMinor,
            currency: currency,
          ),
      if (draft.discountMinor > 0)
        _ChargeRow(
          label: 'receipt_discount'.tr(),
          minor: -draft.discountMinor,
          currency: currency,
          onTap: () => _showAmountDialog(
            context,
            'receipt_discount'.tr(),
            discountController,
          ),
        ),
      if (draft.tipMinor > 0)
        _ChargeRow(
          label: 'receipt_tip'.tr(),
          minor: draft.tipMinor,
          currency: currency,
          onTap: () =>
              _showAmountDialog(context, 'receipt_tip'.tr(), tipController),
        )
      else
        _LinkRow(
          label: 'receipt_tip'.tr(),
          action: 'bf_scan_review_add_tip'.tr(),
          onTap: () =>
              _showAmountDialog(context, 'receipt_tip'.tr(), tipController),
        ),
    ];

    return Container(
      key: const ValueKey('scan-review-charges'),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows,
          _LinkRow(
            label: '',
            action: 'bf_scan_review_edit_charges'.tr(),
            onTap: () => _showAllChargesDialog(context),
          ),
          Divider(height: 12, color: p.border),
          Semantics(
            container: true,
            label:
                '${'total'.tr()} ${formatMoneyMinor(draft.grandTotalMinor, currency)}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'total'.tr(),
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  MoneyText(
                    key: const ValueKey('scan-review-total'),
                    minor: draft.grandTotalMinor,
                    currency: currency,
                    tone: MoneyTone.neutral,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- dialogs

  Future<void> _showPhoto(BuildContext context) async {
    final file = image;
    if (file == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(
                file,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(height: 200),
              ),
            ),
            PositionedDirectional(
              top: 8,
              end: 8,
              child: ScanRoundButton(
                icon: AppIcons.close,
                label: 'close'.tr(),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDetailsDialog(BuildContext context) async {
    final name = TextEditingController(text: restaurantController.text);
    var date = selectedDate;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          final p = context.palette;
          String dateText;
          try {
            dateText = DateFormat.yMMMd().format(date);
          } catch (_) {
            dateText = date.toIso8601String().substring(0, 10);
          }
          return _ReviewDialog(
            title: 'bf_scan_review_edit_details'.tr(),
            onSave: () => Navigator.of(dialogContext).pop(true),
            onCancel: () => Navigator.of(dialogContext).pop(false),
            children: [
              AppTextField(
                controller: name,
                autofocus: true,
                label: 'receipt_store_name'.tr(),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: AppRadii.rowShape(p.border),
                  alignment: AlignmentDirectional.centerStart,
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) setLocal(() => date = picked);
                },
                icon: const Icon(AppIcons.calendar, size: 18),
                label: Text(dateText),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true) {
      restaurantController.text = name.text.trim();
      if (date != selectedDate) onDateChanged(date);
      onSave();
      AppHaptics.selection();
    }
    disposeAfterRouteCloses([name]);
  }

  Future<void> _showAmountDialog(
    BuildContext context,
    String label,
    TextEditingController target,
  ) async {
    final local = TextEditingController(
      text: (parseMinorInput(target.text, currencyCode) ?? 0) == 0
          ? ''
          : minorToInputText(
              parseMinorInput(target.text, currencyCode)!,
              currencyCode,
            ),
    );
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => _ReviewDialog(
          title: label,
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onSave: () {
            final text = local.text.trim();
            if (text.isNotEmpty &&
                parseMinorInput(text, currencyCode) == null) {
              setLocal(() => error = 'bf_scan_amount_invalid'.tr());
              return;
            }
            Navigator.of(dialogContext).pop(true);
          },
          children: [
            _AmountField(
              controller: local,
              label: label,
              currency: currencyCode,
              errorText: error,
              autofocus: true,
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      final minor = parseMinorInput(local.text, currencyCode) ?? 0;
      target.text = minorToInputText(minor, currencyCode);
      onSave();
      AppHaptics.selection();
    }
    disposeAfterRouteCloses([local]);
  }

  Future<void> _showAllChargesDialog(BuildContext context) async {
    final fields = <(String, TextEditingController)>[
      ('receipt_tax'.tr(), taxController),
      ('receipt_service_charge'.tr(), serviceController),
      ('receipt_tip'.tr(), tipController),
      ('receipt_delivery_fee'.tr(), deliveryController),
      ('receipt_discount'.tr(), discountController),
    ];
    String initial(TextEditingController c) {
      final minor = parseMinorInput(c.text, currencyCode) ?? 0;
      return minor == 0 ? '' : minorToInputText(minor, currencyCode);
    }

    final locals = [
      for (final f in fields) TextEditingController(text: initial(f.$2)),
    ];
    final errors = List<String?>.filled(fields.length, null);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => _ReviewDialog(
          title: 'bf_scan_review_edit_charges'.tr(),
          onCancel: () => Navigator.of(dialogContext).pop(false),
          onSave: () {
            var ok = true;
            for (var i = 0; i < locals.length; i++) {
              final text = locals[i].text.trim();
              final bad =
                  text.isNotEmpty &&
                  parseMinorInput(text, currencyCode) == null;
              errors[i] = bad ? 'bf_scan_amount_invalid'.tr() : null;
              if (bad) ok = false;
            }
            if (!ok) {
              setLocal(() {});
              return;
            }
            Navigator.of(dialogContext).pop(true);
          },
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              _AmountField(
                controller: locals[i],
                label: fields[i].$1,
                currency: currencyCode,
                errorText: errors[i],
              ),
              if (i < fields.length - 1) const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
    if (saved == true) {
      for (var i = 0; i < fields.length; i++) {
        final minor = parseMinorInput(locals[i].text, currencyCode) ?? 0;
        fields[i].$2.text = minorToInputText(minor, currencyCode);
      }
      onSave();
      AppHaptics.selection();
    }
    disposeAfterRouteCloses(locals);
  }

  Future<void> _showItemEditorDialog(BuildContext context, {int? index}) async {
    final existing = index == null ? null : itemControllers[index];
    final items = _items;
    final itemData = index != null && index < items.length
        ? items[index]
        : null;
    final note = itemData?['confidence_note']?.toString().trim() ?? '';
    final name = TextEditingController(text: existing?['name']?.text ?? '');
    final qty = TextEditingController(text: existing?['qty']?.text ?? '1');
    final existingPrice = parseMinorInput(
      existing?['price']?.text ?? '',
      currencyCode,
    );
    final price = TextEditingController(
      text: existingPrice == null
          ? ''
          : minorToInputText(existingPrice, currencyCode),
    );
    String? nameError;
    String? qtyError;
    String? priceError;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          final p = context.palette;
          return _ReviewDialog(
            title: index == null
                ? 'receipt_add_item'.tr()
                : 'receipt_edit_item'.tr(),
            onCancel: () => Navigator.of(dialogContext).pop(),
            onSave: () {
              nameError = name.text.trim().isEmpty
                  ? 'bf_scan_item_name_required'.tr()
                  : null;
              qtyError = parseQuantityInput(qty.text) == null
                  ? 'bf_scan_qty_invalid'.tr()
                  : null;
              priceError = parseMinorInput(price.text, currencyCode) == null
                  ? 'bf_scan_amount_invalid'.tr()
                  : null;
              if (nameError != null || qtyError != null || priceError != null) {
                setLocal(() {});
                return;
              }
              Navigator.of(dialogContext).pop('save');
            },
            extra: index == null
                ? null
                : TextButton.icon(
                    onPressed: () => Navigator.of(dialogContext).pop('delete'),
                    style: TextButton.styleFrom(foregroundColor: p.error),
                    icon: const Icon(AppIcons.delete, size: 18),
                    label: Text('receipt_delete_item'.tr()),
                  ),
            children: [
              if (note.isNotEmpty && index != null && _isFlagged(index)) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.oweSoft,
                    borderRadius: AppRadii.rowRadius,
                  ),
                  child: Text(
                    note,
                    style: AppTypography.bodySmall.copyWith(
                      color: p.oweInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                controller: name,
                autofocus: index == null,
                label: 'receipt_item'.tr(),
                errorText: nameError,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: AppTextField(
                      controller: qty,
                      label: 'receipt_qty'.tr(),
                      errorText: qtyError,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _AmountField(
                      controller: price,
                      label: 'receipt_price'.tr(),
                      currency: currencyCode,
                      errorText: priceError,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (result == 'save') {
      final minor = parseMinorInput(price.text, currencyCode) ?? 0;
      final qtyValue = parseQuantityInput(qty.text) ?? 1;
      final priceText = minorToInputText(minor, currencyCode);
      if (index == null) {
        onAddItem(name.text.trim(), '$qtyValue', priceText);
      } else {
        onUpdateItem(index, name.text.trim(), '$qtyValue', priceText);
      }
      AppHaptics.selection();
    } else if (result == 'delete' && index != null) {
      onDeleteItem(index);
      AppHaptics.light();
    }
    disposeAfterRouteCloses([name, qty, price]);
  }

  bool _isFlagged(int index) {
    final banner = buildReviewBanner(
      items: _items,
      currency: currencyCode,
      currentTotalMinor: 0,
      reasons: [
        for (final r
            in (receiptData['needs_review_reasons'] as List? ?? const []))
          r.toString(),
      ],
    );
    return banner?.flaggedItemIndexes.contains(index) ?? false;
  }
}

// --------------------------------------------------------------- pieces

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.controllers,
    required this.currency,
    required this.flagged,
    required this.draft,
    required this.onTapItem,
    required this.onAddItem,
  });

  final List<Map<String, TextEditingController>> controllers;
  final String currency;
  final Set<int> flagged;
  final BillDraft draft;
  final ValueChanged<int> onTapItem;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = <Widget>[];
    for (var i = 0; i < controllers.length; i++) {
      final c = controllers[i];
      final name = c['name']?.text.trim() ?? '';
      final qty = parseQuantityInput(c['qty']?.text ?? '') ?? 1;
      final unit = parseMinorInput(c['price']?.text ?? '', currency) ?? 0;
      final line = unit * qty;
      final isFlagged = flagged.contains(i);
      rows.add(
        Semantics(
          button: true,
          label:
              '$qty × $name, ${formatMoneyMinor(line, currency)}'
              '${isFlagged ? ', ${'bf_scan_review_needs_check'.tr()}' : ''}',
          hint: 'receipt_edit_item'.tr(),
          excludeSemantics: true,
          child: Material(
            color: isFlagged ? p.oweSoft : Colors.transparent,
            child: InkWell(
              key: ValueKey('scan-review-item-$i'),
              onTap: () => onTapItem(i),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : Border(top: BorderSide(color: p.borderSubtle)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTypography.bodyLarge.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isFlagged ? p.oweInk : p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$qty × ${formatMoneyMinor(unit, currency)}',
                            style: AppTypography.bodySmall.copyWith(
                              fontFeatures: AppTypography.tabularFigures,
                              color: isFlagged ? p.oweInk : p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isFlagged) ...[
                      Icon(AppIcons.warning, size: 16, color: p.oweInk),
                      const SizedBox(width: 6),
                    ],
                    MoneyText(
                      minor: line,
                      currency: currency,
                      tone: MoneyTone.neutral,
                      showSymbol: false,
                      style: AppTypography.amount.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: AppTypography.tabularFigures,
                        color: isFlagged ? p.oweInk : p.textPrimary,
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
    return Container(
      key: const ValueKey('scan-review-items'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...rows,
          InkWell(
            onTap: onAddItem,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              decoration: BoxDecoration(
                border: rows.isEmpty
                    ? null
                    : Border(top: BorderSide(color: p.borderSubtle)),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.add, size: 18, color: p.accent),
                  const SizedBox(width: 6),
                  Text(
                    'receipt_add_item'.tr(),
                    style: AppTypography.labelLarge.copyWith(color: p.accent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({
    required this.label,
    required this.minor,
    required this.currency,
    this.onTap,
  });

  final String label;
  final int minor;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            MoneyText(
              minor: minor,
              currency: currency,
              tone: MoneyTone.neutral,
              showSymbol: false,
              size: MoneySize.small,
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      hint: 'common_edit'.tr(),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rowRadius,
        child: row,
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.action,
    required this.onTap,
  });

  final String label;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        if (label.isNotEmpty)
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
          ),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: p.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 44),
              ),
              child: Text(action, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.label,
    required this.currency,
    this.errorText,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String currency;
  final String? errorText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppTextField(
      controller: controller,
      autofocus: autofocus,
      label: label,
      errorText: errorText,
      hint: minorToInputText(0, currency),
      money: true,
      keyboardType: TextInputType.numberWithOptions(
        decimal: currencyDecimals(currency) > 0,
      ),
      textAlign: TextAlign.end,
      prefix: Text(
        currency,
        style: AppTypography.labelMedium.copyWith(color: p.textSecondary),
      ),
    );
  }
}

class _ReviewDialog extends StatelessWidget {
  const _ReviewDialog({
    required this.title,
    required this.children,
    required this.onSave,
    required this.onCancel,
    this.extra,
  });

  final String title;
  final List<Widget> children;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTypography.titleLarge.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
            if (extra != null) ...[
              const SizedBox(height: AppSpacing.md),
              Align(alignment: AlignmentDirectional.centerStart, child: extra),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: Text('common_cancel'.tr()),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: onSave,
                    child: Text('save_changes'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
