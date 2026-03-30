import 'package:flutter/material.dart';
import 'widgets/custom_app_header.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/split_bill_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
// import 'package:flutter_contacts/flutter_contacts.dart';

class ManualEntryScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? participants;
  const ManualEntryScreen({super.key, this.participants});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _storeController = TextEditingController();
  final _itemController = TextEditingController();
  final _qtyController = TextEditingController(text: "1");
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<Map<String, dynamic>> _items = [];

  // Focus Nodes
  final _itemFocusNode = FocusNode();
  final _qtyFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();

  @override
  void dispose() {
    _storeController.dispose();
    _itemController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _itemFocusNode.dispose();
    _qtyFocusNode.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  void _addItem() {
    String name = _itemController.text.trim();
    String priceText = _priceController.text.trim();
    String qtyText = _qtyController.text.trim();

    if (name.isEmpty) {
      HapticFeedback.vibrate();
      return;
    }

    double? price = double.tryParse(priceText);
    int qty = int.tryParse(qtyText) ?? 1;

    if (price == null || qty <= 0) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.lightImpact();

    final newItem = {'name': name, 'price': price, 'qty': qty};

    setState(() {
      _items.insert(0, newItem);
    });

    _listKey.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 400),
    );

    _itemController.clear();
    _priceController.clear();
    _qtyController.text = "1"; // Reset to 1
    _itemFocusNode.requestFocus();
  }

  void _removeItem(int index) {
    HapticFeedback.mediumImpact();

    final removedItem = _items[index];

    setState(() {
      _items.removeAt(index);
    });

    // We pass a key to the builder to ensure it doesn't get confused
    _listKey.currentState?.removeItem(
      index,
      (context, animation) =>
          _buildItemTile(removedItem, animation, index, isRemoving: true),
      duration: const Duration(milliseconds: 300),
    );
  }

  void _finish() {
    if (_formKey.currentState?.validate() != true) {
      HapticFeedback.heavyImpact();
      return;
    }

    if (_items.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('add_at_least_one_item').tr(),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();

    // Calculate total logic
    double total = _items.fold(
      0,
      (sum, item) => sum + ((item['price'] as double) * (item['qty'] as int)),
    );

    final currencyCode =
        Provider.of<AppSettingsProvider>(context, listen: false).currencyCode;
    final manualReceiptData = {
      'storeName': _storeController.text.trim(),
      'total': total,
      'items': List.from(_items),
      'date': _selectedDate.toString(),
      'taxAmount': 0.0,
      'serviceChargeAmount': 0.0,
      'discountAmount': 0.0,
      'currencyCode': currencyCode,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SplitBillScreen(
          receiptData: manualReceiptData,
          initialParticipants: widget.participants,
        ),
      ),
    );
  }

  double get _currentTotal => _items.fold(
    0,
    (sum, item) => sum + ((item['price'] as double) * (item['qty'] as int)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fieldFill = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.7,
    );
    final currencyCode = context.watch<AppSettingsProvider>().currencyCode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppHeader(
        title: 'enter_manually'.tr(),
        infoMessage: 'manual_entry_quick_tips'.tr(),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // 1. INPUT FORM CARD
              Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.brightness == Brightness.dark
                            ? 0.18
                            : 0.08,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _storeController,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: 'receipt_store_name'.tr(),
                          prefixIcon: Icon(
                            Icons.storefront_rounded,
                            color: colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: fieldFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'store_name_required'.tr()
                            : null,
                      ),
                      const SizedBox(height: 16),
                      // DATE PICKER
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme.copyWith(
                                        primary: Theme.of(context).colorScheme.primary, // header background color
                                        onPrimary: Colors.white, // header text color
                                        onSurface: Theme.of(context).colorScheme.onSurface, // body text color
                                      ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: fieldFill,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  DateFormat.yMMMd().format(_selectedDate),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              Icon(
                                Icons.edit_calendar_rounded,
                                color: theme.hintColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ITEM NAME
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _itemController,
                              focusNode: _itemFocusNode,
                              textCapitalization: TextCapitalization.sentences,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                labelText: 'receipt_item'.tr(),
                                hintText: 'burger'.tr(),
                                prefixIcon: const Icon(
                                  Icons.fastfood_rounded,
                                  size: 18,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: fieldFill,
                              ),
                              onFieldSubmitted: (_) => FocusScope.of(
                                context,
                              ).requestFocus(_qtyFocusNode),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // QTY
                          Expanded(
                            flex: 1, // Small width
                            child: TextFormField(
                              controller: _qtyController,
                              focusNode: _qtyFocusNode,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                labelText: 'receipt_qty'.tr(),
                                hintText: '1'.tr(),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: fieldFill,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 16,
                                ),
                              ),
                              onFieldSubmitted: (_) => FocusScope.of(
                                context,
                              ).requestFocus(_priceFocusNode),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // PRICE
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _priceController,
                              focusNode: _priceFocusNode,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                labelText: 'receipt_price'.tr(),
                                prefixIcon: Container(
                                  width: 45,
                                  alignment: Alignment.center,
                                  child: Text(
                                    currencyCode,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: fieldFill,
                              ),
                              onFieldSubmitted: (_) => _addItem(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: Text(
                            'add_to_list',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ).tr(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. LIST SECTION
              Expanded(
                child: Stack(
                  children: [
                    if (_items.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/animations/empty.json',
                              height: 150,
                              errorBuilder: (c, e, s) => Icon(
                                Icons.receipt_long_rounded,
                                size: 80,
                                color: colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'your_list_is_empty',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.54,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ).tr(),
                          ],
                        ),
                      ),

                    AnimatedList(
                      key: _listKey,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      initialItemCount: _items.length,
                      itemBuilder: (context, index, animation) {
                        // Safety check for index
                        if (index >= _items.length) {
                          // This can happen during removal animation if not careful,
                          // but since we passed removedItem to the builder manually in _removeItem,
                          // we should be fine. However, initially _items has the data.
                          return const SizedBox();
                        }
                        return _buildItemTile(_items[index], animation, index);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      // BOTTOM SUMMARY BAR
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.18 : 0.05,
              ),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'total_estimate',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.54),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ).tr(),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyUtils.format(
                      _currentTotal,
                      currencyCode: currencyCode,
                    ),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                  shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                ),
                child: Row(
                  children: [
                    Text(
                      'common_continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ).tr(),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemTile(
    Map<String, dynamic> item,
    Animation<double> animation,
    int index, {
    bool isRemoving = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fieldFill = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.7,
    );
    double lineTotal = (item['price'] as double) * (item['qty'] as int);
    final currencyCode = context.read<AppSettingsProvider>().currencyCode;

    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: UniqueKey(), // Ensure unique key for each item
            direction: DismissDirection.endToStart,
            onDismissed: (_) {
              if (!isRemoving) {
                _removeItem(index);
              }
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.redAccent,
                size: 28,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.14 : 0.05,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Animated Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Lottie.asset(
                        'assets/animations/food.json',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.fastfood, color: Colors.orange),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: fieldFill,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'quantity_times'.tr(
                                  namedArgs: {'qty': item['qty'].toString()},
                                ),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'unit_price_at'.tr(
                                namedArgs: {
                                  'price': CurrencyUtils.format(
                                    (item['price'] as num).toDouble(),
                                    currencyCode: currencyCode,
                                  ),
                                },
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.58,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Price
                  Text(
                    CurrencyUtils.format(lineTotal, currencyCode: currencyCode),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Delete Button (only if not already removing)
                  if (!isRemoving)
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.32),
                      ),
                      onPressed: () => _removeItem(index),
                      splashRadius: 20,
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
