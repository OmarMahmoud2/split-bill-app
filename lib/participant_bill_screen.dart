import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:split_bill_app/widgets/success_state_widget.dart';
import 'services/notification_service.dart';
import 'package:easy_localization/easy_localization.dart';

class ParticipantBillScreen extends StatefulWidget {
  final String billId;
  final String billName;

  const ParticipantBillScreen({
    super.key,
    required this.billId,
    required this.billName,
  });

  @override
  State<ParticipantBillScreen> createState() => _ParticipantBillScreenState();
}

class _ParticipantBillScreenState extends State<ParticipantBillScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;
  bool _showSuccess = false;
  String? _selectedMethod;
  String? _selectedMethodValue;

  String _currencyCode(Map<String, dynamic> billData) =>
      (billData['currencyCode'] ?? billData['currency_code'] ?? 'USD')
          .toString();

  List<Map<String, dynamic>> _otherCharges(Map<String, dynamic> billData) {
    final charges = billData['charges'] as Map<String, dynamic>? ?? {};
    return List<Map<String, dynamic>>.from(charges['otherCharges'] ?? const []);
  }

  // --- MATH LOGIC ---
  Map<String, dynamic> _calculateMyShare(Map<String, dynamic> billData) {
    if (user == null) return {};

    double myItemsTotal = 0.0;
    List<Map<String, dynamic>> myItems = [];

    List<dynamic> items = billData['items'] ?? [];
    for (var item in items) {
      List<dynamic> assigned = item['assignedTo'] ?? [];
      if (assigned.contains(user!.uid)) {
        double price = (item['price'] as num).toDouble();
        int qty = (item['qty'] as num? ?? 1).toInt();
        double totalItemPrice = price * qty;
        double mySplit = totalItemPrice / assigned.length;
        myItemsTotal += mySplit;

        myItems.add({
          'name': item['name'],
          'qty': qty,
          'originalPrice': price,
          'mySplit': mySplit,
          'sharedCount': assigned.length,
          'isShared': assigned.length > 1,
        });
      }
    }

    double grandTotalItems = 0.0;
    for (var item in items) {
      grandTotalItems +=
          (item['price'] as num).toDouble() * (item['qty'] as num? ?? 1);
    }
    if (grandTotalItems == 0) grandTotalItems = 1;

    double myRatio = myItemsTotal / grandTotalItems;

    double tax = ((billData['charges']['taxAmount'] ?? 0) as num).toDouble();
    double service = ((billData['charges']['serviceCharge'] ?? 0) as num)
        .toDouble();
    double tip = ((billData['charges']['tipAmount'] ?? 0) as num).toDouble();
    double discount = ((billData['charges']['discountAmount'] ?? 0) as num)
        .toDouble();
    double delivery = ((billData['charges']['deliveryFeeAmount'] ?? 0) as num)
        .toDouble();
    final participantCount =
        (billData['participants'] as List?)?.length ?? 1;
    final otherChargeShares = _otherCharges(billData).map((charge) {
      final amount = ((charge['amount'] as num?)?.toDouble() ?? 0.0);
      final splitMethod = charge['splitMethod'] ?? charge['split_method'];
      final share = splitMethod == 'equal'
          ? amount / participantCount
          : amount * myRatio;
      return {
        'label': (charge['label'] ?? 'Other Charge').toString(),
        'amount': share,
      };
    }).where((charge) => (charge['amount'] as double) > 0).toList();
    final otherChargesTotal = otherChargeShares.fold<double>(
      0.0,
      (runningTotal, charge) => runningTotal + (charge['amount'] as double),
    );

    double myTax = tax * myRatio;
    double myService = service * myRatio;
    double myTip = tip * myRatio;
    double myDiscount = discount * myRatio;
    double myDelivery = delivery / participantCount;
    double myTotal =
        myItemsTotal +
        myTax +
        myService +
        myTip +
        myDelivery +
        otherChargesTotal -
        myDiscount;

    return {
      'myItems': myItems,
      'myItemsTotal': myItemsTotal,
      'myTax': myTax,
      'myService': myService,
      'myTip': myTip,
      'myDelivery': myDelivery,
      'otherChargeShares': otherChargeShares,
      'myDiscount': myDiscount,
      'myTotal': myTotal,
      'currencyCode': _currencyCode(billData),
    };
  }

  // --- UPLOAD PROOF ---
  Future<void> _uploadPaymentProof() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 25,
      maxWidth: 800,
    );

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      List<int> imageBytes = await image.readAsBytes();
      String base64Image = "data:image/jpeg;base64,${base64Encode(imageBytes)}";
      String? hostId;
      String? storeName;

      DocumentReference billRef = FirebaseFirestore.instance
          .collection('bills')
          .doc(widget.billId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(billRef);
        if (!snapshot.exists) throw Exception("Bill not found");
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

        hostId = data['hostId'];
        storeName = data['storeName'] ?? widget.billName;
        List<dynamic> participants = List.from(data['participants']);

        int myIndex = participants.indexWhere((p) => p['id'] == user!.uid);
        if (myIndex != -1) {
          participants[myIndex]['paymentProof'] = base64Image;
          participants[myIndex]['status'] = 'REVIEW';
          participants[myIndex]['paymentTime'] = Timestamp.now();
        }
        transaction.update(billRef, {'participants': participants});
      });

      if (hostId != null) {
        DocumentSnapshot hostDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(hostId)
            .get();
        if (hostDoc.exists) {
          String? hostToken = hostDoc.get('fcmToken');
          if (hostToken != null) {
            String methodText = _selectedMethod != null
                ? "via ${_getPrettyMethodName(_selectedMethod!)}"
                : "";
            final currentBillData =
                (await billRef.get()).data() as Map<String, dynamic>;
            double myTotal = _calculateMyShare(currentBillData)['myTotal'];

            await NotificationService().sendNotification(
              targetToken: hostToken,
              targetUid: hostId!,
              title: 'payment_received'.tr(),
              body:
                  "${user?.displayName ?? 'A friend'} paid ${CurrencyUtils.format(myTotal, currencyCode: _currencyCode(currentBillData))} $methodText for $storeName.",
              data: {
                'billId': widget.billId,
                'type': 'payment_proof',
                'amount': myTotal.toString(),
                'method': _selectedMethod ?? 'unknown',
                'paymentValue': _selectedMethodValue ?? 'n/a',
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            );
          }
        }
      }

      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markAsPaidNoProof() async {
    setState(() => _isLoading = true);

    try {
      String? hostId;

      DocumentReference billRef = FirebaseFirestore.instance
          .collection('bills')
          .doc(widget.billId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(billRef);
        if (!snapshot.exists) throw Exception("Bill not found");
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

        hostId = data['hostId'];
        List<dynamic> participants = List.from(data['participants']);

        int myIndex = participants.indexWhere((p) => p['id'] == user!.uid);
        if (myIndex != -1) {
          participants[myIndex]['paymentProof'] = null; // No proof
          participants[myIndex]['status'] = 'REVIEW';
          participants[myIndex]['paymentTime'] = Timestamp.now();
        }
        transaction.update(billRef, {'participants': participants});
      });

      if (hostId != null) {
        // Send Notification (Simplified)
        DocumentSnapshot hostDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(hostId)
            .get();
        if (hostDoc.exists) {
          String? hostToken = hostDoc.get('fcmToken');
          if (hostToken != null) {
            final currentBillData =
                (await billRef.get()).data() as Map<String, dynamic>;
            double myTotal = _calculateMyShare(currentBillData)['myTotal'];

            await NotificationService().sendNotification(
              targetToken: hostToken,
              targetUid: hostId!,
              title: 'payment_marked_as_sent'.tr(),
              body:
                  "${user?.displayName ?? 'A friend'} marked ${CurrencyUtils.format(myTotal, currencyCode: _currencyCode(currentBillData))} as paid (No Proof).",
              data: {
                'billId': widget.billId,
                'type': 'payment_proof', // Keep same type for handler
              },
            );
          }
        }
      }

      setState(() {
        _isLoading = false;
        _showSuccess = true;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  void _showPaymentActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('confirm_payment',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ).tr(),
            const SizedBox(height: 8),
            Text('help_the_host_verify_your_payment_faster',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ).tr(),
            const SizedBox(height: 32),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.image_rounded, color: Colors.blue),
              ),
              title: Text('upload_screenshot',
                style: TextStyle(fontWeight: FontWeight.bold),
              ).tr(),
              subtitle: Text('recommended_for_digital_wallets').tr(),
              onTap: () {
                Navigator.pop(context);
                _uploadPaymentProof();
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.orange,
                ),
              ),
              title: Text('i_paid_skip_proof',
                style: TextStyle(fontWeight: FontWeight.bold),
              ).tr(),
              subtitle: Text('host_will_verify_manually').tr(),
              onTap: () {
                Navigator.pop(context);
                _markAsPaidNoProof();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildHeader(String storeName) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text('bill_details',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue[800],
                    letterSpacing: 1.5,
                  ),
                ).tr(),
                Text(
                  storeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Placeholder for symmetry
        ],
      ),
    );
  }

  Widget _buildTotalCard(
    double total,
    String hostName,
    String status,
    String currencyCode,
  ) {
    Color statusColor = status == 'PAID'
        ? Colors.green
        : (status == 'REVIEW' ? Colors.orange : Colors.blue[800]!);
    String statusLabel = status == 'PAID'
        ? "PAID"
        : (status == 'REVIEW' ? "IN REVIEW" : "YOU OWE");

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('you_owe_to',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ).tr(),
              Text(
                hostName,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyUtils.format(total, currencyCode: currencyCode),
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptSection(Map<String, dynamic> calc) {
    List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
      calc['myItems'],
    );
    final currencyCode = (calc['currencyCode'] as String?) ?? 'USD';

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Lottie.asset(
                      'assets/animations/food.json',
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.receipt_long_rounded,
                        size: 60,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('receipt_breakdown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.grey,
                      ),
                    ).tr(),
                    const SizedBox(height: 24),

                    // Headers
                    Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text('receipt_qty',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ).tr(),
                        ),
                        Expanded(
                          child: Text('item_s',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ).tr(),
                        ),
                        Text('receipt_price',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ).tr(),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(thickness: 1, height: 1),
                    ),

                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                "${item['qty']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (item['isShared'])
                                    Text(
                                      "Shared with ${item['sharedCount']}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyUtils.format(
                                item['mySplit'] as double,
                                currencyCode: currencyCode,
                                decimalDigits: 1,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.only(top: 16, bottom: 8),
                      child: Divider(thickness: 1, height: 1),
                    ),

                    _buildBillRow("Subtotal", calc['myItemsTotal'], currencyCode),
                    if (calc['myTax'] > 0)
                      _buildBillRow("Tax Share", calc['myTax'], currencyCode),
                    if (calc['myService'] > 0)
                      _buildBillRow(
                        "Service Share",
                        calc['myService'],
                        currencyCode,
                      ),
                    if (calc['myTip'] > 0)
                      _buildBillRow("Tip Share", calc['myTip'], currencyCode),
                    if (calc['myDelivery'] > 0)
                      _buildBillRow(
                        "Delivery Share",
                        calc['myDelivery'],
                        currencyCode,
                      ),
                    ...(calc['otherChargeShares'] as List<dynamic>).map(
                      (charge) => _buildBillRow(
                        (charge['label'] ?? 'Other Charge').toString(),
                        charge['amount'] as double,
                        currencyCode,
                      ),
                    ),
                    if (calc['myDiscount'] > 0)
                      _buildBillRow(
                        "Discount Share",
                        -calc['myDiscount'],
                        currencyCode,
                        isDiscount: true,
                      ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: DottedLine(),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('total',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ).tr(),
                        Text(
                          CurrencyUtils.format(
                            calc['myTotal'] as double,
                            currencyCode: currencyCode,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Top Cutouts
        Positioned(
          top: 16 - 7.5,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              15,
              (index) => Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        // Bottom Cutouts
        Positioned(
          bottom: 16 - 7.5,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              15,
              (index) => Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBillRow(
    String label,
    double amount,
    String currencyCode, {
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            "${isDiscount ? "-" : ""}${CurrencyUtils.format(amount.abs(), currencyCode: currencyCode, decimalDigits: 1)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isDiscount ? Colors.red : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods(String hostId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(hostId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return LoadingStateWidget(
            message: 'retrieving_payment_methods'.tr(),
          );
        }

        if (snapshot.hasError) {
          return Text('error_loading_payment_methods').tr();
        }

        if (!snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>?;

        // 1. Try New Format (List)
        List<dynamic> rawList = userData?['customPaymentMethods'] ?? [];
        if (rawList.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Text('select_payment_method',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1,
                    color: Colors.grey,
                  ),
                ).tr(),
              ),
              ...rawList.map((item) {
                final map = item as Map<String, dynamic>;
                return _buildPaymentCard(
                  map['name'] ?? 'Method',
                  map['value'] ?? '',
                );
              }),
              const SizedBox(height: 100), // Space for FAB
            ],
          );
        }

        // 2. Fallback to Old Format (Map)
        var methods =
            userData?['paymentMethods'] as Map<String, dynamic>? ?? {};
        var validMethods = methods.entries
            .where((e) => e.value != null && e.value.toString().isNotEmpty)
            .toList();

        if (validMethods.isEmpty) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: Text('host_hasn_t_added_payment_methods_yet',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ).tr(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Text('select_payment_method',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1,
                  color: Colors.grey,
                ),
              ).tr(),
            ),
            ...validMethods.map(
              (entry) => _buildPaymentCard(entry.key, entry.value.toString()),
            ),
            const SizedBox(height: 100), // Space for FAB
          ],
        );
      },
    );
  }

  Widget _buildPaymentCard(String method, String value) {
    bool isSelected = _selectedMethod == method;
    String displayTitle = _getPrettyMethodName(method);

    // --- LOGO DETECTION LOGIC ---
    String lowerMethod = method.toLowerCase();
    String lowerValue = value.toLowerCase();
    String assetPath = 'assets/payments/ewallet.jpg'; // Default

    if (lowerMethod.contains('instapay') || lowerValue.contains('instapay')) {
      assetPath = 'assets/payments/instapay.png';
    } else if (lowerMethod.contains('paypal') ||
        lowerValue.contains('paypal')) {
      assetPath = 'assets/payments/paypal.jpg';
    } else if (lowerMethod.contains('venmo') || lowerValue.contains('venmo')) {
      assetPath = 'assets/payments/venmo.png';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [Colors.blue[900]!, Colors.blue[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(colors: [Colors.white, Colors.white]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.blue.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: isSelected
            ? Border.all(color: Colors.transparent)
            : Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);

            setState(() {
              _selectedMethod = method;
              _selectedMethodValue = value;
            });

            HapticFeedback.lightImpact();

            // Check if it's a link
            if (value.startsWith('http')) {
              final Uri url = Uri.parse(value);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
                return;
              }
            }

            Clipboard.setData(ClipboardData(text: value));
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'selection_copied'.tr(
                    namedArgs: {'label': displayTitle},
                  ),
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green[700],
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // LOGO / ICON
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.payment_rounded,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // TEXT DETAILS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // ACTION INDICATOR
                if (value.startsWith('http'))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white24
                          : Colors.blue.withValues(alpha: 0.1), // Fixed opacity usage
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('pay',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.blue[800],
                          ),
                        ).tr(),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 14,
                          color: isSelected ? Colors.white : Colors.blue[800],
                        ),
                      ],
                    ),
                  )
                else
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.copy_rounded,
                    color: isSelected ? Colors.white : Colors.grey[400],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPrettyMethodName(String method) {
    if (method == 'instapay') return "InstaPay";
    if (method == 'wallet') return "Vodafone Cash / Wallet";
    if (method == 'iban') return "Bank IBAN";
    return method.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bills')
                .doc(widget.billId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return LoadingStateWidget(
                  message: 'checking_payments'.tr(),
                );
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text('bill_not_found').tr());
              }

              var data = snapshot.data!.data() as Map<String, dynamic>;
              String hostId = data['hostId'];
              String hostName = data['hostName'] ?? "Host";
              final currencyCode = _currencyCode(data);

              var me = (data['participants'] as List).firstWhere(
                (p) => p['id'] == user?.uid,
                orElse: () => {},
              );
              String status = me['status'] ?? 'PENDING';
              var calc = _calculateMyShare(data);

              return SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(data['storeName'] ?? widget.billName),
                      _buildTotalCard(
                        calc['myTotal'],
                        hostName,
                        status,
                        currencyCode,
                      ),
                      _buildReceiptSection(calc),
                      if (status == 'PENDING') _buildPaymentMethods(hostId),
                      if (status == 'REVIEW')
                        _buildStatusInfo(
                          "PAYMENT UNDER REVIEW",
                          "The host has been notified and is checking your payment proof.",
                          Colors.orange,
                          status,
                        ),
                      if (status == 'PAID')
                        _buildStatusInfo(
                          "FULLY SETTLED",
                          "You've successfully paid your share. Thank you!",
                          Colors.green,
                          status,
                        ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              );
            },
          ),

          // Action Button (Only if PENDING)
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bills')
                .doc(widget.billId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              var data = snapshot.data!.data() as Map<String, dynamic>;
              var me = (data['participants'] as List).firstWhere(
                (p) => p['id'] == user?.uid,
                orElse: () => {},
              );
              if (me['status'] != 'PENDING') return const SizedBox.shrink();

              return Positioned(
                bottom: 30,
                left: 16,
                right: 16,
                child: ElevatedButton.icon(
                  onPressed: _showPaymentActionSheet,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text('i_ve_paid',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ).tr(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[900],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 65),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 10,
                  ),
                ),
              );
            },
          ),

          // --- OVERLAYS ---
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.95),
              child: LoadingStateWidget(message: 'uploading_proof'.tr()),
            ),

          if (_showSuccess)
            Container(
              color: Colors.white,
              child: SuccessStateWidget(
                message: 'payment_sent'.tr(),
                actionLabel: 'got_it'.tr(),
                onAction: () => setState(() => _showSuccess = false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo(
    String title,
    String subtitle,
    Color color,
    String currentStatus,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            currentStatus == 'PAID'
                ? Icons.check_circle_rounded
                : Icons.access_time_filled_rounded,
            color: color,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class DottedLine extends StatelessWidget {
  const DottedLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        40,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.transparent : Colors.grey[300],
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
