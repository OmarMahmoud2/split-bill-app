import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/utils/currency_utils.dart';

class ReceiptResultView extends StatelessWidget {
  final Map<String, dynamic> receiptData;
  final String? editingSection;
  final List<Map<String, TextEditingController>> itemControllers;
  final String currencyCode;
  final TextEditingController restaurantController;
  final TextEditingController totalController;
  final TextEditingController taxController;
  final TextEditingController serviceController;
  final TextEditingController discountController;
  final TextEditingController tipController;
  final TextEditingController deliveryController;
  final ValueChanged<String?> onEditingSectionChanged;
  final VoidCallback onSave;
  final VoidCallback onAddItem;
  final void Function(int index) onDeleteItem;

  const ReceiptResultView({
    super.key,
    required this.receiptData,
    required this.editingSection,
    required this.itemControllers,
    required this.currencyCode,
    required this.restaurantController,
    required this.totalController,
    required this.taxController,
    required this.serviceController,
    required this.discountController,
    required this.tipController,
    required this.deliveryController,
    required this.onEditingSectionChanged,
    required this.onSave,
    required this.onAddItem,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(totalController.text) ?? 0.0;
    final tax = double.tryParse(taxController.text) ?? 0.0;
    final service = double.tryParse(serviceController.text) ?? 0.0;
    final discount = double.tryParse(discountController.text) ?? 0.0;
    final tip = double.tryParse(tipController.text) ?? 0.0;
    final delivery = double.tryParse(deliveryController.text) ?? 0.0;
    final receiptItems = List<Map<String, dynamic>>.from(
      (receiptData['items'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final otherCharges = List<Map<String, dynamic>>.from(
      (receiptData['other_charges'] as List? ?? const []).map(
        (charge) => Map<String, dynamic>.from(charge as Map),
      ),
    );
    final confidenceScores = Map<String, dynamic>.from(
      receiptData['confidence_scores'] ?? const {},
    );
    final isEditingHeader = editingSection == 'header';
    final isEditingItems = editingSection == 'items';
    final isEditingCharges = editingSection == 'charges';

    double currentSubtotal = 0;
    for (var controllers in itemControllers) {
      final qty = double.tryParse(controllers['qty']!.text) ?? 0;
      final price = double.tryParse(controllers['price']!.text) ?? 0;
      currentSubtotal += qty * price;
    }

    final dateStr = DateTime.now().toString().substring(0, 10);
    final timeStr = TimeOfDay.now().format(context);
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 24),
            SizedBox(
              height: 100,
              child: Lottie.asset(
                'assets/animations/food.json',
                repeat: true,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.receipt_long_rounded,
                  size: 72,
                  color: Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: isEditingHeader
                        ? _buildSmallEditField(
                            controller: restaurantController,
                            label: 'receipt_store_name'.tr(),
                            isBold: true,
                            fontSize: 20,
                          )
                        : Text(
                            receiptData['restaurant_name']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
                                    true
                                ? receiptData['restaurant_name']
                                : 'receipt_store_name'.tr(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  _buildSectionEditButton(
                    isEditing: isEditingHeader,
                    onTap: () {
                      if (isEditingHeader) {
                        onSave();
                        onEditingSectionChanged(null);
                      } else {
                        onEditingSectionChanged('header');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "$dateStr  |  $timeStr",
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'receipt_total_payment'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    CurrencyUtils.format(total, currencyCode: currencyCode),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'receipt_item'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.4,
                      color: muted,
                    ),
                  ),
                  const Spacer(),
                  _buildSectionEditButton(
                    isEditing: isEditingItems,
                    onTap: () {
                      if (isEditingItems) {
                        onSave();
                        onEditingSectionChanged(null);
                      } else {
                        onEditingSectionChanged('items');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (isEditingItems)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onAddItem,
                    icon: const Icon(Icons.add_rounded),
                    label: Text('receipt_add_item'.tr()),
                  ),
                ),
              ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemControllers.length,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemBuilder: (context, idx) {
                final nameController = itemControllers[idx]['name']!;
                final qtyController = itemControllers[idx]['qty']!;
                final priceController = itemControllers[idx]['price']!;
                final itemData = idx < receiptItems.length
                    ? receiptItems[idx]
                    : const <String, dynamic>{};

                if (isEditingItems) {
                  return _buildEditableItemCard(
                    context,
                    itemData: itemData,
                    nameController: nameController,
                    qtyController: qtyController,
                    priceController: priceController,
                    onDelete: () => onDeleteItem(idx),
                  );
                }

                return _buildReadOnlyItemCard(
                  context,
                  itemData: itemData,
                  nameController: nameController,
                  qtyController: qtyController,
                  priceController: priceController,
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(height: 32),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    'receipt_charges'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.4,
                      color: muted,
                    ),
                  ),
                  const Spacer(),
                  _buildSectionEditButton(
                    isEditing: isEditingCharges,
                    onTap: () {
                      if (isEditingCharges) {
                        onSave();
                        onEditingSectionChanged(null);
                      } else {
                        onEditingSectionChanged('charges');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildChargeRow(
              context,
              'receipt_subtotal'.tr(),
              currentSubtotal,
              confidenceScore: _score(confidenceScores['subtotal']),
            ),
            if (isEditingCharges) ...[
              _buildChargeEditRow(
                'receipt_tax'.tr(),
                taxController,
                confidenceScore: _score(confidenceScores['tax_amount']),
              ),
              _buildChargeEditRow(
                'receipt_service_charge'.tr(),
                serviceController,
                confidenceScore: _score(confidenceScores['service_charge']),
              ),
              _buildChargeEditRow(
                'receipt_discount'.tr(),
                discountController,
                confidenceScore: _score(confidenceScores['discount_amount']),
              ),
              _buildChargeEditRow(
                'receipt_tip'.tr(),
                tipController,
                confidenceScore: _score(confidenceScores['tip_amount']),
              ),
              _buildChargeEditRow(
                'receipt_delivery_fee'.tr(),
                deliveryController,
                confidenceScore: _score(confidenceScores['delivery_fee']),
              ),
            ] else ...[
              if (tax > 0)
                _buildChargeRow(
                  context,
                  'receipt_tax'.tr(),
                  tax,
                  confidenceScore: _score(confidenceScores['tax_amount']),
                ),
              if (service > 0)
                _buildChargeRow(
                  context,
                  'receipt_service_charge'.tr(),
                  service,
                  confidenceScore: _score(confidenceScores['service_charge']),
                ),
              if (discount > 0)
                _buildChargeRow(
                  context,
                  'receipt_discount'.tr(),
                  discount,
                  isNegative: true,
                  confidenceScore: _score(confidenceScores['discount_amount']),
                ),
              if (tip > 0)
                _buildChargeRow(
                  context,
                  'receipt_tip'.tr(),
                  tip,
                  confidenceScore: _score(confidenceScores['tip_amount']),
                ),
              if (delivery > 0)
                _buildChargeRow(
                  context,
                  'receipt_delivery_fee'.tr(),
                  delivery,
                  confidenceScore: _score(confidenceScores['delivery_fee']),
                ),
            ],
            if (otherCharges.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'receipt_other_charges'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...otherCharges.map(
                (charge) => _buildChargeRow(
                  context,
                  charge['label']?.toString() ?? 'receipt_other_charge_label'.tr(),
                  (charge['amount'] as num?)?.toDouble() ?? 0.0,
                  confidenceScore: _score(charge['confidence_score']),
                  confidenceNote: charge['confidence_note']?.toString(),
                ),
              ),
            ],
            const SizedBox(height: 40),
            Text(
              'receipt_thank_you'.tr(),
              style: TextStyle(
                letterSpacing: 4,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableItemCard(
    BuildContext context, {
    required Map<String, dynamic> itemData,
    required TextEditingController nameController,
    required TextEditingController qtyController,
    required TextEditingController priceController,
    required VoidCallback onDelete,
  }) {
    final score = _score(itemData['confidence_score']);
    final palette = _confidencePalette(score);
    final badge = _buildConfidenceChip(score);
    final note = itemData['confidence_note']?.toString().trim() ?? '';
    final qty = double.tryParse(qtyController.text) ?? 0.0;
    final price = double.tryParse(priceController.text) ?? 0.0;
    final lineTotal = qty * price;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSmallEditField(
                      controller: nameController,
                      label: 'receipt_item'.tr(),
                    ),
                    if (badge != null || (note.isNotEmpty && _shouldHighlight(score))) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (badge != null) badge,
                          if (note.isNotEmpty && _shouldHighlight(score))
                            Container(
                              constraints: const BoxConstraints(maxWidth: 230),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: palette.border),
                              ),
                              child: Text(
                                note,
                                style: TextStyle(
                                  color: palette.accent,
                                  fontSize: 11,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                tooltip: 'receipt_delete_item'.tr(),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _fieldWidthFor(
                  qtyController.text,
                  minWidth: 82,
                  maxWidth: 110,
                  charWidth: 16,
                ),
                child: _buildSmallEditField(
                  controller: qtyController,
                  label: 'receipt_qty'.tr(),
                  isNumber: true,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildInfoPill(
                    label:
                        "${'receipt_line_total'.tr()}: ${CurrencyUtils.format(lineTotal, currencyCode: currencyCode)}",
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSmallEditField(
            controller: priceController,
            label: 'receipt_price'.tr(),
            isNumber: true,
            isBold: true,
            fontSize: 16,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyItemCard(
    BuildContext context, {
    required Map<String, dynamic> itemData,
    required TextEditingController nameController,
    required TextEditingController qtyController,
    required TextEditingController priceController,
  }) {
    final score = _score(itemData['confidence_score']);
    final palette = _confidencePalette(score);
    final badge = _buildConfidenceChip(score);
    final note = itemData['confidence_note']?.toString().trim() ?? '';
    final qty = double.tryParse(qtyController.text) ?? 1.0;
    final price = double.tryParse(priceController.text) ?? 0.0;
    final lineTotal =
        (itemData['line_total'] as num?)?.toDouble() ?? (qty * price);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  nameController.text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (badge != null) badge,
              const SizedBox(width: 8),
              Text(
                CurrencyUtils.format(lineTotal, currencyCode: currencyCode),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoPill(
                label: "x${_formatQty(qty)}",
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey.shade800,
              ),
              _buildInfoPill(
                label:
                    "${'receipt_price'.tr()}: ${CurrencyUtils.format(price, currencyCode: currencyCode)}",
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey.shade800,
              ),
            ],
          ),
          if (note.isNotEmpty && _shouldHighlight(score)) ...[
            const SizedBox(height: 10),
            Text(
              note,
              style: TextStyle(
                color: palette.accent,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallEditField({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
    bool isBold = false,
    double fontSize = 14,
    TextAlign textAlign = TextAlign.left,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: readOnly ? Colors.grey[600] : Colors.black,
      ),
      maxLines: 1,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.white,
        isDense: false,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00B365), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
    );
  }

  Widget _buildSectionEditButton({
    required bool isEditing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isEditing ? const Color(0xFF00B365) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            isEditing ? Icons.check_rounded : Icons.edit_outlined,
            size: 18,
            color: isEditing ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildChargeEditRow(
    String label,
    TextEditingController controller, {
    double confidenceScore = 1.0,
  }) {
    final palette = _confidencePalette(confidenceScore);
    final badge = _buildConfidenceChip(confidenceScore);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (badge != null) ...[
              badge,
              const SizedBox(width: 10),
            ],
            SizedBox(
              width: _fieldWidthFor(
                controller.text,
                minWidth: 110,
                maxWidth: 190,
                charWidth: 14,
              ),
              child: _buildSmallEditField(
                controller: controller,
                label: label,
                isNumber: true,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChargeRow(
    BuildContext context,
    String label,
    double value, {
    bool isNegative = false,
    double confidenceScore = 1.0,
    String? confidenceNote,
  }) {
    final palette = _confidencePalette(confidenceScore);
    final badge = _buildConfidenceChip(confidenceScore);
    final note = confidenceNote?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ),
                if (badge != null) ...[
                  badge,
                  const SizedBox(width: 10),
                ],
                Text(
                  "${isNegative ? '-' : ''}${CurrencyUtils.format(value, currencyCode: currencyCode)}",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (note.isNotEmpty && _shouldHighlight(confidenceScore)) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  note,
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget? _buildConfidenceChip(double score) {
    final key = _confidenceChipKey(score);
    if (key == null) return null;
    final palette = _confidencePalette(score);
    return _buildInfoPill(
      label: key.tr(),
      backgroundColor: Colors.white,
      foregroundColor: palette.accent,
    );
  }

  String? _confidenceChipKey(double score) {
    if (score < 0.72) {
      return 'receipt_review_chip';
    }
    if (score < 0.88) {
      return 'receipt_check_chip';
    }
    return null;
  }

  bool _shouldHighlight(double score) => score < 0.88;

  double _score(dynamic rawValue, {double fallback = 0.92}) {
    if (rawValue is num) {
      return rawValue.clamp(0.0, 1.0).toDouble();
    }
    return fallback;
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(1);
  }

  double _fieldWidthFor(
    String value, {
    required double minWidth,
    required double maxWidth,
    double charWidth = 12,
  }) {
    final trimmed = value.trim();
    final estimated = trimmed.isEmpty
        ? minWidth
        : (trimmed.length * charWidth) + 48;
    return estimated.clamp(minWidth, maxWidth).toDouble();
  }

  _ConfidencePalette _confidencePalette(double score) {
    if (score < 0.72) {
      return _ConfidencePalette(
        background: Colors.red.shade50,
        border: Colors.red.shade200,
        accent: Colors.red.shade700,
      );
    }
    if (score < 0.88) {
      return _ConfidencePalette(
        background: Colors.amber.shade50,
        border: Colors.amber.shade200,
        accent: Colors.amber.shade800,
      );
    }
    return _ConfidencePalette(
      background: Colors.white,
      border: Colors.grey.shade200,
      accent: Colors.green.shade700,
    );
  }
}

class _ConfidencePalette {
  final Color background;
  final Color border;
  final Color accent;

  const _ConfidencePalette({
    required this.background,
    required this.border,
    required this.accent,
  });
}
