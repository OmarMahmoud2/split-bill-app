import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:split_bill_app/widgets/success_state_widget.dart';
import 'package:split_bill_app/widgets/empty_state_widget.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSuccess = false;
  List<Map<String, dynamic>> _methods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    if (user == null) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (doc.exists && doc.data() is Map) {
        var data = doc.data() as Map<String, dynamic>;

        // 1. Try new format first (List)
        if (data['customPaymentMethods'] != null) {
          _methods = List<Map<String, dynamic>>.from(
            data['customPaymentMethods'],
          );
        }
        // 2. Fallback & Migrate old format (Map)
        else if (data['paymentMethods'] != null) {
          var oldMethods = data['paymentMethods'] as Map<String, dynamic>;
          oldMethods.forEach((key, value) {
            if (value.toString().trim().isNotEmpty) {
              _methods.add({
                'name': key.toUpperCase(),
                'value': value.toString(),
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading payment methods: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (user == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'customPaymentMethods': _methods});

      setState(() {
        _isSaving = false;
        _isSuccess = true;
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addMethod() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final valueController = TextEditingController();
        String selectedMethod = "Instapay";
        final List<String> methodOptions = [
          "Instapay",
          "PayPal",
          "Venmo",
          "E-Wallet",
          "Other",
        ];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                "New Payment Method",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    decoration: InputDecoration(
                      labelText: "Method Type",
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: methodOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setDialogState(() => selectedMethod = newValue);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedMethod == "Other") ...[
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Custom Method Name",
                        hintText: "e.g. Cash App",
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(
                      labelText: selectedMethod == "Instapay"
                          ? "Instapay Link / Username"
                          : "Details (Link/Number)",
                      hintText: selectedMethod == "Instapay"
                          ? "https://ipn.eg/..."
                          : "Required details",
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    String finalName = selectedMethod == "Other"
                        ? nameController.text.trim()
                        : selectedMethod;

                    if (finalName.isNotEmpty &&
                        valueController.text.isNotEmpty) {
                      setState(() {
                        _methods.add({
                          'name': finalName,
                          'value': valueController.text.trim(),
                        });
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editMethod(int index) {
    final methodData = _methods[index];
    final String currentName = methodData['name'];
    final String currentValue = methodData['value'];

    final List<String> methodOptions = [
      "Instapay",
      "PayPal",
      "Venmo",
      "E-Wallet",
      "Other",
    ];

    bool isOther = !methodOptions.contains(currentName);
    String selectedMethod = isOther ? "Other" : currentName;

    final nameController = TextEditingController(
      text: isOther ? currentName : "",
    );
    final valueController = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                "Edit Method",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    decoration: InputDecoration(
                      labelText: "Method Type",
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: methodOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setDialogState(() => selectedMethod = newValue);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedMethod == "Other") ...[
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: "Custom Method Name",
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(
                      labelText: "Details",
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _methods.removeAt(index));
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Remove",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    String finalName = selectedMethod == "Other"
                        ? nameController.text.trim()
                        : selectedMethod;

                    if (finalName.isNotEmpty &&
                        valueController.text.isNotEmpty) {
                      setState(() {
                        _methods[index] = {
                          'name': finalName,
                          'value': valueController.text.trim(),
                        };
                      });
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "How it works",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Add your preferred ways to get paid. These details will be shown to your friends when you split a bill so they can pay you easily!",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it!"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isSaving
          ? const LoadingStateWidget(message: "Saving settings...")
          : _isSuccess
          ? SuccessStateWidget(
              message: "Payment methods updated!",
              onAction: () => Navigator.pop(context),
            )
          : CustomScrollView(
              slivers: [
                // 1. PREMIUM HEADER
                SliverToBoxAdapter(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              "Payment Methods",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _showInfo,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  color: Theme.of(context).primaryColor,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. LIST OF METHODS
                if (_isLoading)
                  const SliverFillRemaining(
                    child: LoadingStateWidget(
                      message: "Loading your methods...",
                    ),
                  )
                else if (_methods.isEmpty)
                  const SliverFillRemaining(
                    child: EmptyStateWidget(
                      message: "No payment methods added yet.",
                      title: 'Add your payment methods',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final method = _methods[index];
                        return _buildMethodTile(method, index);
                      }, childCount: _methods.length),
                    ),
                  ),

                // Bottom Spacing for FAB
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      // 3. BOTTOM ACTIONS (only show when not loading/saving/success)
      floatingActionButton: (!_isLoading && !_isSaving && !_isSuccess)
          ? Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 4,
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    onPressed: _addMethod,
                    backgroundColor: Theme.of(context).primaryColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildMethodTile(Map<String, dynamic> method, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _editMethod(index),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.payment_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        method['value'],
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.edit_note_rounded,
                  color: Colors.grey,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
