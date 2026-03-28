import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/utils/currency_utils.dart';

class ReceiptResultView extends StatelessWidget {
  final Map<String, dynamic> receiptData;
  final bool isEditing;
  final List<Map<String, TextEditingController>> itemControllers;
  final String currencyCode;
  final TextEditingController restaurantController;
  final TextEditingController totalController;
  final TextEditingController taxController;
  final TextEditingController serviceController;
  final TextEditingController discountController;
  final TextEditingController tipController;
  final TextEditingController deliveryController;
  final VoidCallback onSave;
  final VoidCallback onAddItem;
  final void Function(int index) onDeleteItem;
  final VoidCallback onCancel;

  const ReceiptResultView({
    super.key,
    required this.receiptData,
    required this.isEditing,
    required this.itemControllers,
    required this.currencyCode,
    required this.restaurantController,
    required this.totalController,
    required this.taxController,
    required this.serviceController,
    required this.discountController,
    required this.tipController,
    required this.deliveryController,
    required this.onSave,
    required this.onAddItem,
    required this.onDeleteItem,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(totalController.text) ?? 0.0;
    final tax = double.tryParse(taxController.text) ?? 0.0;
    final service = double.tryParse(serviceController.text) ?? 0.0;
    final discount = double.tryParse(discountController.text) ?? 0.0;
    final tip = double.tryParse(tipController.text) ?? 0.0;
    final delivery = double.tryParse(deliveryController.text) ?? 0.0;
    final otherCharges = List<Map<String, dynamic>>.from(
      receiptData['other_charges'] ?? const [],
    );

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
              child: Lottie.asset('assets/animations/food.json', repeat: true),
            ),
            const SizedBox(height: 12),
            if (isEditing)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildSmallEditField(
                  controller: restaurantController,
                  label: 'receipt_store_name'.tr(),
                  isBold: true,
                  fontSize: 20,
                ),
              )
            else
              Text(
                receiptData['restaurant_name'] ?? "Unknown Store",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: onSurface,
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
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'receipt_item'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'receipt_qty'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'receipt_total'.tr(),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  if (isEditing) const SizedBox(width: 36),
                ],
              ),
            ),
            if (isEditing)
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

                if (isEditing) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildSmallEditField(
                            controller: nameController,
                            label: 'receipt_item'.tr(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSmallEditField(
                            controller: qtyController,
                            label: 'receipt_qty'.tr(),
                            isNumber: true,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSmallEditField(
                            controller: priceController,
                            label: 'receipt_price'.tr(),
                            isNumber: true,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        IconButton(
                          onPressed: () => onDeleteItem(idx),
                          tooltip: 'receipt_delete_item'.tr(),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  );
                }

                final qty = double.tryParse(qtyController.text) ?? 1.0;
                final price = double.tryParse(priceController.text) ?? 0.0;
                final lineTotal = qty * price;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          nameController.text,
                          style: TextStyle(color: muted, fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "x${qty.toStringAsFixed(0)}",
                          style: TextStyle(color: muted, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          CurrencyUtils.format(
                            lineTotal,
                            currencyCode: currencyCode,
                          ),
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(height: 32),
            ),
            _buildChargeRow(
              context,
              'receipt_subtotal'.tr(),
              currentSubtotal,
            ),
            if (isEditing) ...[
              _buildChargeEditRow('receipt_tax'.tr(), taxController),
              _buildChargeEditRow(
                'receipt_service_charge'.tr(),
                serviceController,
              ),
              _buildChargeEditRow('receipt_discount'.tr(), discountController),
              _buildChargeEditRow('receipt_tip'.tr(), tipController),
              _buildChargeEditRow(
                'receipt_delivery_fee'.tr(),
                deliveryController,
              ),
            ] else ...[
              if (tax > 0)
                _buildChargeRow(context, 'receipt_tax'.tr(), tax),
              if (service > 0)
                _buildChargeRow(
                  context,
                  'receipt_service_charge'.tr(),
                  service,
                ),
              if (discount > 0)
                _buildChargeRow(
                  context,
                  'receipt_discount'.tr(),
                  discount,
                  isNegative: true,
                ),
              if (tip > 0)
                _buildChargeRow(context, 'receipt_tip'.tr(), tip),
              if (delivery > 0)
                _buildChargeRow(
                  context,
                  'receipt_delivery_fee'.tr(),
                  delivery,
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
                  charge['label']?.toString() ?? 'Other',
                  (charge['amount'] as num?)?.toDouble() ?? 0.0,
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
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00B365)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildChargeEditRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          SizedBox(
            width: 140,
            child: _buildSmallEditField(
              controller: controller,
              label: label,
              isNumber: true,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargeRow(
    BuildContext context,
    String label,
    double value, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
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
    );
  }
}
