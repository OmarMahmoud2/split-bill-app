import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'services/notification_service.dart';
import 'screens/guest_bill/widgets/guest_header.dart';
import 'screens/guest_bill/widgets/download_section.dart';
import 'screens/guest_bill/guest_selector_view.dart';
import 'utils/currency_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

class GuestBillScreen extends StatefulWidget {
  final String billId;
  final String? initialParticipantId;

  const GuestBillScreen({
    super.key,
    required this.billId,
    this.initialParticipantId,
  });

  @override
  State<GuestBillScreen> createState() => _GuestBillScreenState();
}

class _GuestBillScreenState extends State<GuestBillScreen> {
  String? _selectedParticipantId;
  bool _isUploading = false;
  bool _showSuccess = false;
  String? _selectedMethod;
  late Future<DocumentSnapshot> _billFuture;

  @override
  void initState() {
    super.initState();
    _billFuture = _fetchBill();
    if (widget.initialParticipantId != null) {
      _selectedParticipantId = widget.initialParticipantId;
    }
  }

  @override
  void didUpdateWidget(covariant GuestBillScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.billId != widget.billId) {
      _billFuture = _fetchBill();
      _selectedParticipantId = widget.initialParticipantId;
      _selectedMethod = null;
      _showSuccess = false;
    }
  }

  Future<DocumentSnapshot> _fetchBill() {
    return FirebaseFirestore.instance
        .collection('bills')
        .doc(widget.billId)
        .get()
        .timeout(const Duration(seconds: 12));
  }

  String _currencyCode(Map<String, dynamic> billData) =>
      (billData['currencyCode'] ?? billData['currency_code'] ?? 'USD')
          .toString();

  List<Map<String, dynamic>> _otherCharges(Map<String, dynamic> billData) {
    final charges = billData['charges'] as Map<String, dynamic>? ?? {};
    return List<Map<String, dynamic>>.from(charges['otherCharges'] ?? const []);
  }

  // --- CALCULATE DETAILED BREAKDOWN ---
  Map<String, dynamic> _calculateDetailedShare(
    Map<String, dynamic> billData,
    String participantId,
  ) {
    final items = billData['items'] as List<dynamic>? ?? [];
    final charges = billData['charges'] as Map<String, dynamic>?;

    double myItemsTotal = 0.0;
    List<Map<String, dynamic>> myItems = [];

    // Calculate assigned items
    for (int i = 0; i < items.length; i++) {
      var item = items[i];
      List assignedTo = item['assignedTo'] ?? [];

      if (assignedTo.contains(participantId)) {
        double price = (item['price'] as num).toDouble();
        int qty = (item['qty'] as num? ?? 1).toInt();
        double totalPrice = price * qty;
        double mySplit = totalPrice / assignedTo.length;
        myItemsTotal += mySplit;

        myItems.add({
          'name': item['name'],
          'qty': qty,
          'originalPrice': price,
          'mySplit': mySplit,
          'sharedCount': assignedTo.length,
          'isShared': assignedTo.length > 1,
        });
      }
    }

    // Calculate grand total of all items
    double grandTotalItems = 0.0;
    for (var item in items) {
      grandTotalItems +=
          (item['price'] as num).toDouble() * (item['qty'] as num? ?? 1);
    }
    if (grandTotalItems == 0) grandTotalItems = 1;

    double myRatio = myItemsTotal / grandTotalItems;

    double tax = ((charges?['taxAmount'] ?? 0) as num).toDouble();
    double service = ((charges?['serviceCharge'] ?? 0) as num).toDouble();
    double tip = ((charges?['tipAmount'] ?? 0) as num).toDouble();
    double discount = ((charges?['discountAmount'] ?? 0) as num).toDouble();
    double delivery = ((charges?['deliveryFeeAmount'] ?? 0) as num).toDouble();
    final participantCount = (billData['participants'] as List?)?.length ?? 1;
    final otherChargeShares = _otherCharges(billData)
        .map((charge) {
          final amount = ((charge['amount'] as num?)?.toDouble() ?? 0.0);
          final splitMethod = charge['splitMethod'] ?? charge['split_method'];
          final share = splitMethod == 'equal'
              ? amount / participantCount
              : amount * myRatio;
          return {
            'label': (charge['label'] ?? 'receipt_other_charge_label'.tr())
                .toString(),
            'amount': share,
          };
        })
        .where((charge) => (charge['amount'] as double) > 0)
        .toList();
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

  // --- SHOW BREAKDOWN MODAL ---
  void _showBreakdownModal(
    BuildContext context,
    Map<String, dynamic> billData,
    String participantName,
  ) {
    final breakdown = _calculateDetailedShare(
      billData,
      _selectedParticipantId!,
    );
    List<Map<String, dynamic>> myItems = List<Map<String, dynamic>>.from(
      breakdown['myItems'],
    );
    final currencyCode = breakdown['currencyCode'] as String;

    PremiumBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'participant_bill_title'.tr(
                  namedArgs: {'name': participantName},
                ),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                billData['storeName'] ?? 'receipt'.tr(),
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Scrollable Content
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items Section
                  Text(
                    'your_items',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ).tr(),
                  const SizedBox(height: 16),

                  if (myItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'no_items_assigned_to_you',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ).tr(),
                      ),
                    )
                  else
                    ...myItems.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'quantity_suffix'.tr(
                                    namedArgs: {'qty': item['qty'].toString()},
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                  if (item['isShared'])
                                    Text(
                                      'shared_with_people_count'.tr(
                                        namedArgs: {
                                          'count': item['sharedCount']
                                              .toString(),
                                        },
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyUtils.format(
                                item['mySplit'] as double,
                                currencyCode: currencyCode,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Charges Breakdown
                  _buildRow(
                    'items_subtotal'.tr(),
                    breakdown['myItemsTotal'],
                    currencyCode,
                  ),
                  if (breakdown['myTax'] > 0) ...[
                    const SizedBox(height: 12),
                    _buildRow(
                      'tax_share'.tr(),
                      breakdown['myTax'],
                      currencyCode,
                    ),
                  ],
                  if (breakdown['myService'] > 0) ...[
                    const SizedBox(height: 12),
                    _buildRow(
                      'receipt_service_charge'.tr(),
                      breakdown['myService'],
                      currencyCode,
                    ),
                  ],
                  if (breakdown['myTip'] > 0) ...[
                    const SizedBox(height: 12),
                    _buildRow(
                      'tip_share'.tr(),
                      breakdown['myTip'],
                      currencyCode,
                    ),
                  ],
                  if (breakdown['myDelivery'] > 0) ...[
                    const SizedBox(height: 12),
                    _buildRow(
                      'delivery_share'.tr(),
                      breakdown['myDelivery'],
                      currencyCode,
                    ),
                  ],
                  ...(breakdown['otherChargeShares'] as List<dynamic>).expand(
                    (charge) => [
                      const SizedBox(height: 12),
                      _buildRow(
                        (charge['label'] ?? 'receipt_other_charge_label'.tr())
                            .toString(),
                        (charge['amount'] as num).toDouble(),
                        currencyCode,
                      ),
                    ],
                  ),
                  if (breakdown['myDiscount'] > 0) ...[
                    const SizedBox(height: 12),
                    _buildRow(
                      'receipt_discount'.tr(),
                      -breakdown['myDiscount'],
                      currencyCode,
                      isDiscount: true,
                    ),
                  ],

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'total_due',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ).tr(),
                        Text(
                          CurrencyUtils.format(
                            breakdown['myTotal'] as double,
                            currencyCode: currencyCode,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    double amount,
    String currencyCode, {
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
        Text(
          "${isDiscount ? '-' : ''}${CurrencyUtils.format(amount.abs(), currencyCode: currencyCode)}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDiscount ? Colors.red : Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _updateSelectedParticipantPayment({
    required String billId,
    required String? paymentProof,
  }) async {
    final selectedParticipantId = _selectedParticipantId;
    if (selectedParticipantId == null) {
      throw Exception('guest'.tr());
    }

    final billRef = FirebaseFirestore.instance.collection('bills').doc(billId);

    return FirebaseFirestore.instance.runTransaction<Map<String, dynamic>>((
      transaction,
    ) async {
      final snapshot = await transaction.get(billRef);
      if (!snapshot.exists) throw Exception('bill_not_found'.tr());

      final data = snapshot.data() as Map<String, dynamic>;
      final participants = (data['participants'] as List<dynamic>? ?? const [])
          .map((participant) => Map<String, dynamic>.from(participant as Map))
          .toList();

      final myIndex = participants.indexWhere(
        (participant) => participant['id'] == selectedParticipantId,
      );
      if (myIndex == -1) {
        throw Exception('guest'.tr());
      }

      participants[myIndex] = {
        ...participants[myIndex],
        'paymentProof': paymentProof,
        'status': 'REVIEW',
        'paymentTime': Timestamp.now(),
      };

      transaction.update(billRef, {'participants': participants});
      return data;
    });
  }

  // --- UPLOAD PROOF (FIXED FOR PERMISSIONS) ---
  Future<void> _uploadPaymentProof(
    String billId,
    String hostId,
    String storeName,
    double myTotal,
    String participantName,
  ) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 25,
      maxWidth: 800,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      List<int> imageBytes = await image.readAsBytes();
      String base64Image = "data:image/jpeg;base64,${base64Encode(imageBytes)}";

      final data = await _updateSelectedParticipantPayment(
        billId: billId,
        paymentProof: base64Image,
      );

      // Notify Host
      if (hostId.isNotEmpty) {
        DocumentSnapshot hostDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(hostId)
            .get();
        if (hostDoc.exists) {
          String? hostToken = hostDoc.get('fcmToken');
          if (hostToken != null) {
            final formattedAmount = CurrencyUtils.format(
              myTotal,
              currencyCode: _currencyCode(data),
            );
            await NotificationService().sendNotification(
              targetToken: hostToken,
              targetUid: hostId,
              title: 'payment_received'.tr(),
              body: 'payment_received_body'.tr(
                namedArgs: {
                  'payer': participantName,
                  'amount': formattedAmount,
                  'store': storeName,
                  'method_suffix': '',
                },
              ),
              historyTitleKey: 'payment_received',
              historyBodyKey: 'payment_received_body',
              historyBodyArgs: {
                'payer': participantName,
                'amount': formattedAmount,
                'store': storeName,
                'method_suffix': '',
              },
              data: {
                'billId': billId,
                'type': 'payment_proof',
                'amount': myTotal.toString(),
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _showSuccess = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'error_with_details'.tr(namedArgs: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _markAsPaidNoProof(
    String billId,
    String hostId,
    String storeName,
    double myTotal,
    String participantName,
  ) async {
    setState(() => _isUploading = true);

    try {
      final data = await _updateSelectedParticipantPayment(
        billId: billId,
        paymentProof: null,
      );

      if (hostId.isNotEmpty) {
        DocumentSnapshot hostDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(hostId)
            .get();
        if (hostDoc.exists) {
          String? hostToken = hostDoc.get('fcmToken');
          if (hostToken != null) {
            final formattedAmount = CurrencyUtils.format(
              myTotal,
              currencyCode: _currencyCode(data),
            );
            await NotificationService().sendNotification(
              targetToken: hostToken,
              targetUid: hostId,
              title: 'payment_marked_as_sent'.tr(),
              body: 'payment_marked_as_sent_body'.tr(
                namedArgs: {
                  'payer': participantName,
                  'amount': formattedAmount,
                },
              ),
              historyTitleKey: 'payment_marked_as_sent',
              historyBodyKey: 'payment_marked_as_sent_body',
              historyBodyArgs: {
                'payer': participantName,
                'amount': formattedAmount,
              },
              data: {
                'billId': billId,
                'type': 'payment_proof',
                'amount': myTotal.toString(),
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              },
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _showSuccess = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'error_with_details'.tr(namedArgs: {'error': e.toString()}),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showPaymentActionSheet(
    String billId,
    String hostId,
    String storeName,
    double myTotal,
    String participantName,
  ) {
    PremiumBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'confirm_payment',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ).tr(),
          const SizedBox(height: 8),
          Text(
            'help_the_host_verify_your_payment_faster',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ).tr(),
          const SizedBox(height: 32),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.image_rounded, color: Colors.blue),
            ),
            title: Text(
              'upload_screenshot',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ).tr(),
            subtitle: Text(
              'recommended_for_digital_wallets',
              style: TextStyle(color: Colors.grey[600]),
            ).tr(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: () {
              Navigator.pop(context);
              _uploadPaymentProof(
                billId,
                hostId,
                storeName,
                myTotal,
                participantName,
              );
            },
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
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
            title: Text(
              'i_paid_skip_proof',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ).tr(),
            subtitle: Text(
              'host_will_verify_manually',
              style: TextStyle(color: Colors.grey[600]),
            ).tr(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: () {
              Navigator.pop(context);
              _markAsPaidNoProof(
                billId,
                hostId,
                storeName,
                myTotal,
                participantName,
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTotalCard(
    double myTotal,
    String hostName,
    String status,
    Color statusColor,
    Map<String, dynamic> billData,
    String participantName,
  ) {
    final currencyCode = _currencyCode(billData);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 380;
    String statusLabel = status == 'PAID'
        ? 'status_paid'.tr()
        : (status == 'REVIEW' ? 'in_review'.tr() : 'PENDING');

    return InkWell(
      onTap: () => _showBreakdownModal(context, billData, participantName),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: EdgeInsets.all(isNarrow ? 22 : 28),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: status == 'REVIEW'
                  ? Colors.amber.withValues(alpha: 0.15)
                  : statusColor.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor, width: 2),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text.rich(
              TextSpan(
                text: '${'you_owe_to'.tr()} ',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                children: [
                  TextSpan(
                    text: hostName,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Text(
              CurrencyUtils.format(myTotal, currencyCode: currencyCode),
              style: TextStyle(
                fontSize: isNarrow ? 38 : 48,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
                color: colorScheme.primary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 6),
                Text(
                  'tap_to_see_breakdown',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ).tr(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper to determine payment type and get colors/assets
  Map<String, dynamic> _getPaymentMethodStyle(String methodName, String value) {
    String lowerName = methodName.toLowerCase();
    String lowerValue = value.toLowerCase();

    if (lowerName.contains('instapay') || lowerValue.contains('instapay')) {
      return {
        'color': const Color(0xFF4A148C), // Deep Purple
        'gradient': [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)],
        'icon': Icons.qr_code_2_rounded,
        'logo': 'assets/payments/instapay.png',
        'isLink': true,
      };
    } else if (lowerName.contains('vodafone') ||
        lowerValue.contains('vodafone')) {
      return {
        'color': const Color(0xFFB71C1C), // Red
        'gradient': [const Color(0xFFD32F2F), const Color(0xFFE57373)],
        'icon': Icons.phone_android_rounded,
        'logo': 'assets/payments/vodafone.png', // Assuming asset exists
        'isLink': false,
      };
    } else if (lowerName.contains('paypal') || lowerValue.contains('paypal')) {
      return {
        'color': const Color(0xFF003087), // PayPal Blue
        'gradient': [const Color(0xFF003087), const Color(0xFF009CDE)],
        'icon': Icons.payment_rounded,
        'logo': 'assets/payments/paypal.jpg',
        'isLink': true,
      };
    } else if (lowerName.contains('venmo') || lowerValue.contains('venmo')) {
      return {
        'color': const Color(0xFF3D95CE), // Venmo Blue
        'gradient': [const Color(0xFF3D95CE), const Color(0xFF008CFF)],
        'icon': Icons.attach_money_rounded,
        'logo': 'assets/payments/venmo.png',
        'isLink': true,
      };
    } else {
      // Default / E-Wallet / Bank
      return {
        'color': Colors.blueGrey,
        'gradient': [Colors.blueGrey[700]!, Colors.blueGrey[500]!],
        'icon': Icons.account_balance_wallet_rounded,
        'logo': 'assets/payments/ewallet.jpg',
        'isLink': value.startsWith('http'),
      };
    }
  }

  Widget _buildPaymentMethodCard(String method, String value) {
    final style = _getPaymentMethodStyle(method, value);
    final isSelected = _selectedMethod == method;
    final List<Color> gradientColors = style['gradient'];
    final bool isLink = style['isLink'] || value.startsWith('http');
    final String logoPath = style['logo'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            setState(() => _selectedMethod = method);

            if (isLink) {
              final Uri url = Uri.parse(value);
              if (await canLaunchUrl(url)) {
                // Important: Launch in external application (browser/app)
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('could_not_launch_payment_app').tr(),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } else {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'payment_method_copied'.tr(namedArgs: {'method': method}),
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: isSelected
                    ? gradientColors
                    : [Colors.white, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey[200]!,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Logo Container
                Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      logoPath,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          Icon(style['icon'], color: style['color']),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isSelected ? Colors.white : Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isLink ? "Tap to Pay" : value,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Action Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLink ? Icons.open_in_new_rounded : Icons.copy_rounded,
                    color: isSelected ? Colors.white : Colors.grey[400],
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.billId.isEmpty) {
      return Scaffold(
        body: _buildCenteredState(
          icon: Icons.link_off_rounded,
          title: 'invalid_bill_id'.tr(),
        ),
      );
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      body: FutureBuilder<DocumentSnapshot>(
        future: _billFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final isTimeout = snapshot.error is TimeoutException;
            return _buildCenteredState(
              icon: Icons.cloud_off_rounded,
              title: isTimeout
                  ? 'error_loading_bills'.tr()
                  : 'error_with_details'.tr(
                      namedArgs: {'error': snapshot.error.toString()},
                    ),
              subtitle: isTimeout
                  ? 'Please check your connection and refresh this page.'
                  : null,
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return Center(
              child: Lottie.asset(
                'assets/animations/loading.json',
                width: 180,
                errorBuilder: (c, e, s) => const CircularProgressIndicator(),
              ),
            );
          }

          final rawBillData = snapshot.data!.data();
          if (!snapshot.data!.exists || rawBillData is! Map<String, dynamic>) {
            return _buildCenteredState(
              icon: Icons.receipt_long_rounded,
              title: 'bill_not_found'.tr(),
            );
          }

          final billData = rawBillData;
          final participants = billData['participants'] as List<dynamic>? ?? [];
          final String storeName =
              billData['storeName'] ?? 'unknown_store'.tr();

          // Auto-select logic (only once)
          if (widget.initialParticipantId != null &&
              _selectedParticipantId == null) {
            bool isValid = participants.any(
              (p) => p['id'] == widget.initialParticipantId,
            );
            if (isValid) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(
                    () => _selectedParticipantId = widget.initialParticipantId,
                  );
                }
              });
            }
          }

          final bool showDashboard = _selectedParticipantId != null;

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeInOutBack,
            switchOutCurve: Curves.easeInOutBack, // Smooth transition
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: showDashboard
                ? _buildDashboardView(billData, participants, storeName)
                : GuestSelectorView(
                    participants: participants,
                    storeName: storeName,
                    onParticipantSelected: (id) =>
                        setState(() => _selectedParticipantId = id),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCenteredState({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 44, color: colorScheme.primary),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: 0,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardView(
    Map<String, dynamic> billData,
    List<dynamic> participants,
    String storeName,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 1. Success State
    if (_showSuccess) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/success.json',
                width: 220,
                repeat: false,
                errorBuilder: (c, e, s) => const Icon(
                  Icons.check_circle,
                  size: 120,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'payment_proof_uploaded',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ).tr(),
              const SizedBox(height: 12),
              Text(
                'the_host_has_been_notified_and_will_review_your_payment_soon',
                style: TextStyle(color: Colors.grey, fontSize: 15),
                textAlign: TextAlign.center,
              ).tr(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => setState(() => _showSuccess = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'back_to_bill',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ).tr(),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Loading State
    if (_isUploading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/loading.json',
              width: 180,
              errorBuilder: (c, e, s) => const CircularProgressIndicator(),
            ),
            const SizedBox(height: 24),
            Text(
              'uploading_proof',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ).tr(),
          ],
        ),
      );
    }

    final participant = participants.firstWhere(
      (p) => p['id'] == _selectedParticipantId,
      orElse: () => null,
    );

    if (participant == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedParticipantId = null);
      });
      return GuestSelectorView(
        participants: participants,
        storeName: storeName,
        onParticipantSelected: (id) =>
            setState(() => _selectedParticipantId = id),
      );
    }

    final breakdown = _calculateDetailedShare(
      billData,
      _selectedParticipantId!,
    );
    final double myTotal = breakdown['myTotal'];
    final String hostId = billData['hostId'] ?? '';
    final String hostName = billData['hostName'] ?? 'Host';

    return SingleChildScrollView(
      key: const ValueKey('DashboardView'),
      padding: const EdgeInsets.only(bottom: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              // HEADER
              Stack(
                children: [
                  GuestHeader(storeName: storeName, isCompact: true),
                  Positioned(
                    top: 40,
                    left: 16,
                    child: SafeArea(
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedParticipantId = null;
                            _selectedMethod = null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24), // Spacing between header and content
              // Welcome Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'welcome_back',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface.withValues(alpha: 0.46),
                      ),
                    ).tr(),
                    const SizedBox(height: 8),
                    Text(
                      (participant['name'] ?? 'guest'.tr()).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              // Total Card
              _buildTotalCard(
                myTotal,
                hostName,
                participant['status'] ?? 'PENDING',
                (participant['status'] == 'PAID')
                    ? Colors.green
                    : (participant['status'] == 'REVIEW'
                          ? Colors.amber[700]! // Yellow/Amber for Review
                          : Colors.orange),
                billData,
                participant['name'] ?? "Guest",
              ),

              // Payment Methods
              if (billData['paymentMethods'] != null &&
                  billData['paymentMethods'] is Map &&
                  (billData['paymentMethods'] as Map).isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'pay_with',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                        ).tr(),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                ),
                ...(billData['paymentMethods'] as Map<String, dynamic>).entries
                    .map(
                      (e) => _buildPaymentMethodCard(e.key, e.value.toString()),
                    ),
              ],

              const SizedBox(height: 24),

              // Hide button if Paid OR Review
              if ((participant['status'] ?? 'PENDING') == 'PENDING') ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentActionSheet(
                      widget.billId,
                      hostId,
                      storeName,
                      myTotal,
                      participant['name'] ?? "Guest",
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 24),
                    label: Text(
                      'i_ve_paid',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ).tr(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              const DownloadSection(),
            ],
          ),
        ),
      ),
    );
  }
}
