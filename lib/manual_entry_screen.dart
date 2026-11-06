import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/screens/scan_receipt/amount_input.dart';
import 'package:split_bill_app/screens/scan_receipt/widgets/scan_top_bar.dart';
import 'package:split_bill_app/split_bill_screen.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// A manual line, in minor units.
class ManualItem {
  const ManualItem({
    required this.name,
    required this.unitPriceMinor,
    this.qty = 1,
  });

  final String name;
  final int unitPriceMinor;
  final int qty;

  int get lineTotalMinor => unitPriceMinor * qty;
}

/// The `receiptData` map SplitBillScreen expects from manual entry.
///
/// With no [items], the typed [amountMinor] becomes one item named after
/// [whatFor]. Amounts are stored as major-unit doubles (legacy shape), but
/// derived from minor units so they never drift.
Map<String, dynamic> buildManualReceiptData({
  required String whatFor,
  required List<ManualItem> items,
  required int? amountMinor,
  required DateTime date,
  required String currencyCode,
}) {
  final code = normalizeCurrency(currencyCode);
  final lines = items.isNotEmpty
      ? items
      : [
          if (amountMinor != null && amountMinor > 0)
            ManualItem(name: whatFor, unitPriceMinor: amountMinor),
        ];
  final totalMinor = lines.fold<int>(0, (s, i) => s + i.lineTotalMinor);
  return {
    'storeName': whatFor,
    'total': fromMinorUnits(totalMinor, code),
    'items': [
      for (final i in lines)
        {
          'name': i.name,
          'price': fromMinorUnits(i.unitPriceMinor, code),
          'qty': i.qty,
        },
    ],
    'date': date.toString(),
    'taxAmount': 0.0,
    'serviceChargeAmount': 0.0,
    'discountAmount': 0.0,
    'currencyCode': currencyCode,
    // Marker for analytics (bill_created source); not stored on the bill.
    'entryMode': 'manual',
  };
}

/// "New expense": an amount (or a list of items), what it was for and the
/// date, then on to SplitBillScreen to pick people and the split.
class ManualEntryScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? participants;
  final String? groupId;
  const ManualEntryScreen({super.key, this.participants, this.groupId});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _amountController = TextEditingController();
  final _storeController = TextEditingController();
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();

  final List<ManualItem> _items = [];

  final _itemFocusNode = FocusNode();
  final _qtyFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();

  String? _amountError;
  String? _itemError;
  String? _qtyError;
  String? _priceError;

  @override
  void dispose() {
    _amountController.dispose();
    _storeController.dispose();
    _itemController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _itemFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  String get _currency => context.read<AppSettingsProvider>().currencyCode;

  int get _itemsTotalMinor =>
      _items.fold<int>(0, (s, i) => s + i.lineTotalMinor);

  void _addItem() {
    final currency = _currency;
    final name = _itemController.text.trim();
    final qty = parseQuantityInput(_qtyController.text);
    final price = parseMinorInput(_priceController.text, currency);

    setState(() {
      _itemError = name.isEmpty ? 'bf_scan_item_name_required'.tr() : null;
      _qtyError = qty == null ? 'bf_scan_qty_invalid'.tr() : null;
      _priceError = price == null ? 'bf_scan_amount_invalid'.tr() : null;
    });
    if (name.isEmpty || qty == null || price == null) {
      AppHaptics.error();
      return;
    }

    AppHaptics.light();
    setState(() {
      _items.add(ManualItem(name: name, unitPriceMinor: price, qty: qty));
      _amountError = null;
    });
    _itemController.clear();
    _priceController.clear();
    _qtyController.text = '1';
    _itemFocusNode.requestFocus();
  }

  void _removeItem(int index) {
    AppHaptics.light();
    setState(() => _items.removeAt(index));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      AppHaptics.selection();
      setState(() => _selectedDate = picked);
    }
  }

  void _finish() {
    if (_formKey.currentState?.validate() != true) {
      AppHaptics.error();
      return;
    }
    final currencyCode = _currency;
    final amountMinor = _items.isEmpty
        ? parseMinorInput(_amountController.text, currencyCode)
        : null;
    if (_items.isEmpty && (amountMinor == null || amountMinor <= 0)) {
      setState(() => _amountError = 'bf_scan_manual_need_amount'.tr());
      AppToast.show(
        context,
        message: 'bf_scan_manual_need_amount'.tr(),
        type: AppToastType.error,
      );
      return;
    }

    AppHaptics.selection();
    final manualReceiptData = buildManualReceiptData(
      whatFor: _storeController.text.trim(),
      items: _items,
      amountMinor: amountMinor,
      date: _selectedDate,
      currencyCode: currencyCode,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SplitBillScreen(
          receiptData: manualReceiptData,
          initialParticipants: widget.participants,
          groupId: widget.groupId,
        ),
      ),
    );
  }

  String _dateText() {
    try {
      return DateFormat.yMMMd().format(_selectedDate);
    } catch (_) {
      return _selectedDate.toIso8601String().substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final currencyCode = context.watch<AppSettingsProvider>().currencyCode;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: ScanTopBar(title: 'bf_scan_manual_title'.tr(), close: true),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
            children: [
              _buildAmountHero(p, currencyCode),
              const SizedBox(height: AppSpacing.xxl),
              _label(p, 'bf_scan_manual_what_for'.tr()),
              TextFormField(
                controller: _storeController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'bf_scan_manual_what_for_hint'.tr(),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'bf_scan_manual_what_for_required'.tr()
                    : null,
              ),
              const SizedBox(height: 14),
              _label(p, 'bf_scan_manual_date'.tr()),
              Semantics(
                button: true,
                label: '${'bf_scan_manual_date'.tr()}: ${_dateText()}',
                excludeSemantics: true,
                child: Material(
                  color: p.surface,
                  shape: AppRadii.rowShape(p.border),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _pickDate,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dateText(),
                              style: AppTypography.bodyLarge.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: p.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _buildItemsSection(p, currencyCode),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
          child: FilledButton(
            key: const ValueKey('manual-continue'),
            onPressed: _finish,
            child: Text('common_continue'.tr()),
          ),
        ),
      ),
    );
  }

  Widget _label(AppPalette p, String text) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: 6),
    child: Text(
      text,
      style: AppTypography.labelMedium.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
      ),
    ),
  );

  Widget _buildAmountHero(AppPalette p, String currencyCode) {
    final hasItems = _items.isNotEmpty;
    final decimals = currencyDecimals(currencyCode);
    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          'bf_scan_manual_amount'.tr(),
          style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 6),
        if (hasItems)
          MoneyText(
            key: const ValueKey('manual-amount-total'),
            minor: _itemsTotalMinor,
            currency: currencyCode,
            tone: MoneyTone.neutral,
            size: MoneySize.hero,
            animate: true,
            animateFromZero: false,
          )
        else
          TextField(
            key: const ValueKey('manual-amount-field'),
            controller: _amountController,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.numberWithOptions(
              decimal: decimals > 0,
            ),
            style: AppTypography.amountHero.copyWith(color: p.textPrimary),
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              hintText: formatMoneyMinor(0, currencyCode),
              hintStyle: AppTypography.amountHero.copyWith(
                color: p.textDisabled,
              ),
              errorText: _amountError,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: p.surfaceVariant,
            borderRadius: AppRadii.chipRadius,
          ),
          child: Text(
            hasItems
                ? '$currencyCode · ${'bf_scan_manual_amount_from_items'.tr()}'
                : currencyCode,
            style: AppTypography.labelMedium.copyWith(
              fontSize: 13,
              color: p.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection(AppPalette p, String currencyCode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(p, 'bf_scan_manual_items'.tr()),
        Text(
          'bf_scan_manual_items_hint'.tr(),
          style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _items.length; i++)
                StaggeredEntrance(
                  key: ObjectKey(_items[i]),
                  child: _buildItemRow(p, i, currencyCode),
                ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  16,
                  _items.isEmpty ? 16 : 12,
                  16,
                  16,
                ),
                child: _buildAddRow(p, currencyCode),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(AppPalette p, int index, String currencyCode) {
    final item = _items[index];
    return Container(
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : Border(top: BorderSide(color: p.borderSubtle)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '${item.qty}×',
              style: AppTypography.amountSmall.copyWith(
                fontSize: 13,
                color: p.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.name,
              style: AppTypography.bodyLarge.copyWith(
                fontSize: 15,
                color: p.textPrimary,
              ),
            ),
          ),
          MoneyText(
            minor: item.lineTotalMinor,
            currency: currencyCode,
            tone: MoneyTone.neutral,
            showSymbol: false,
            style: const TextStyle(fontSize: 15),
          ),
          IconButton(
            onPressed: () => _removeItem(index),
            tooltip: 'bf_scan_manual_remove_item'.tr(
              namedArgs: {'name': item.name},
            ),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(
              Icons.remove_circle_outline_rounded,
              size: 20,
              color: p.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddRow(AppPalette p, String currencyCode) {
    final decimals = currencyDecimals(currencyCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _itemController,
                focusNode: _itemFocusNode,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'receipt_item'.tr(),
                  errorText: _itemError,
                ),
                onSubmitted: (_) => _qtyFocusNode.requestFocus(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 64,
              child: TextField(
                controller: _qtyController,
                focusNode: _qtyFocusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'receipt_qty'.tr(),
                  errorText: _qtyError,
                ),
                onSubmitted: (_) => _priceFocusNode.requestFocus(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _priceController,
                focusNode: _priceFocusNode,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: decimals > 0,
                ),
                textAlign: TextAlign.end,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'receipt_price'.tr(),
                  hintText: minorToInputText(0, currencyCode),
                  errorText: _priceError,
                ),
                onSubmitted: (_) => _addItem(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: _addItem,
          icon: Icon(Icons.add_rounded, size: 18, color: p.accent),
          label: Text('add_to_list'.tr()),
        ),
      ],
    );
  }
}
