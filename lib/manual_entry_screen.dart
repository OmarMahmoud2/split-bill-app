import 'package:flutter/material.dart';
import 'widgets/custom_app_header.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/split_bill_screen.dart';
import 'package:lottie/lottie.dart';
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
        const SnackBar(
          content: Text("Add at least one item!"),
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

    final manualReceiptData = {
      'storeName': _storeController.text.trim(),
      'total': total,
      'items': List.from(_items),
      'date': DateTime.now().toString(),
      'taxAmount': 0.0,
      'serviceChargeAmount': 0.0,
      'discountAmount': 0.0,
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
    return Scaffold(
      backgroundColor: Colors.grey[100], // Darker background for contrast
      appBar: CustomAppHeader(
        title: "Enter Manually",
        infoMessage:
            "💡 Quick Tips:\n\n• Add store name at the top\n• Enter each item with quantity and price\n• Tap 'Add to List' or press Enter\n• Swipe items left to delete\n• Review total at bottom\n• Tap 'Continue' when done",
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueGrey.withValues(alpha: 0.08),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: "Store Name",
                          prefixIcon: Icon(
                            Icons.storefront_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? "Store name required"
                            : null,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: "Item",
                                hintText: "Burger",
                                prefixIcon: const Icon(
                                  Icons.fastfood_rounded,
                                  size: 18,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: "Qty",
                                hintText: "1",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                labelText: "Price",
                                prefixIcon: const Icon(
                                  Icons.attach_money_rounded,
                                  size: 18,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text(
                            "Add to List",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
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
                                color: Colors.grey[300],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Your list is empty",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "TOTAL ESTIMATE",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "\$${_currentTotal.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                  shadowColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.4),
                ),
                child: Row(
                  children: const [
                    Text(
                      "Continue",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
    double lineTotal = (item['price'] as double) * (item['qty'] as int);

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
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade100, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade100,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
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
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "x${item['qty']}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "@ \$${item['price']}",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Price
                  Text(
                    "\$${lineTotal.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Delete Button (only if not already removing)
                  if (!isRemoving)
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 20,
                        color: Colors.grey[300],
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
