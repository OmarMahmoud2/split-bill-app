import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class EditBillSummaryDialog extends StatefulWidget {
  final double initialTax;
  final double initialService;
  final double initialTip;
  final double initialDiscount;
  final double initialDelivery;
  final Function(double, double, double, double, double) onConfirm;

  const EditBillSummaryDialog({
    super.key,
    required this.initialTax,
    required this.initialService,
    required this.initialTip,
    required this.initialDiscount,
    required this.initialDelivery,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required double initialTax,
    required double initialService,
    required double initialTip,
    required double initialDiscount,
    required double initialDelivery,
    required Function(double, double, double, double, double) onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (context) => EditBillSummaryDialog(
        initialTax: initialTax,
        initialService: initialService,
        initialTip: initialTip,
        initialDiscount: initialDiscount,
        initialDelivery: initialDelivery,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<EditBillSummaryDialog> createState() => _EditBillSummaryDialogState();
}

class _EditBillSummaryDialogState extends State<EditBillSummaryDialog> {
  late double _tax;
  late double _service;
  late double _tip;
  late double _discount;
  late double _delivery;

  @override
  void initState() {
    super.initState();
    _tax = widget.initialTax;
    _service = widget.initialService;
    _tip = widget.initialTip;
    _discount = widget.initialDiscount;
    _delivery = widget.initialDelivery;
  }

  Widget _buildMoneyInput(
    String label,
    double initial,
    Function(double) onChanged,
  ) {
    return TextFormField(
      initialValue: initial == 0 ? "" : initial.toStringAsFixed(2),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      onChanged: (val) => onChanged(double.tryParse(val) ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: Text('update_summary',
        style: TextStyle(fontWeight: FontWeight.bold),
      ).tr(),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMoneyInput("Tax", _tax, (v) => _tax = v),
            const SizedBox(height: 12),
            _buildMoneyInput("Service", _service, (v) => _service = v),
            const SizedBox(height: 12),
            _buildMoneyInput("Tip", _tip, (v) => _tip = v),
            const SizedBox(height: 12),
            _buildMoneyInput("Delivery", _delivery, (v) => _delivery = v),
            const SizedBox(height: 12),
            _buildMoneyInput("Discount", _discount, (v) => _discount = v),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common_cancel', style: TextStyle(color: Colors.grey)).tr(),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_tax, _service, _tip, _discount, _delivery);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text('save_and_exit').tr(),
        ),
      ],
    );
  }
}
