import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:split_bill_app/config/api_keys.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'success_screen.dart';
import 'services/notification_service.dart';
import 'services/revenue_cat_service.dart';
import 'utils/currency_utils.dart';
import 'widgets/bill_summary_widgets.dart';
import 'widgets/custom_app_header.dart';
import 'package:easy_localization/easy_localization.dart';

class BillSummaryConfirmScreen extends StatefulWidget {
  final Map<String, dynamic> receiptData;
  final List<Map<String, dynamic>> participants;
  final Map<int, List<String>> itemAssignments;
  final Map<int, Map<String, int>> quantityAssignments;
  final double taxAmount;
  final double serviceChargeAmount;
  final double tipAmount;
  final double discountAmount;
  final double deliveryFeeAmount;
  final String? oldBillIdToDelete;
  final String? oldImageToDelete;

  const BillSummaryConfirmScreen({
    super.key,
    required this.receiptData,
    required this.participants,
    required this.itemAssignments,
    required this.quantityAssignments,
    required this.taxAmount,
    required this.serviceChargeAmount,
    required this.tipAmount,
    this.discountAmount = 0.0,
    this.deliveryFeeAmount = 0.0,
    this.oldBillIdToDelete,
    this.oldImageToDelete,
  });

  @override
  State<BillSummaryConfirmScreen> createState() =>
      _BillSummaryConfirmScreenState();
}

class _BillSummaryConfirmScreenState extends State<BillSummaryConfirmScreen> {
  bool _isCreating = false;
  Map<String, double> _finalShares = {};
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  final NotificationService _notificationService = NotificationService();
  String? _rouletteWinnerId;

  // Editing logic
  bool _isEditing = false;
  late TextEditingController _taxController;
  late TextEditingController _serviceController;
  late TextEditingController _tipController;
  late TextEditingController _discountController;
  late TextEditingController _deliveryFeeController;

  String get _currencyCode => widget.receiptData['currency_code'] ?? 'USD';

  List<Map<String, dynamic>> get _otherCharges => List<Map<String, dynamic>>.from(
    widget.receiptData['other_charges'] ?? const [],
  );

  double get _otherChargesTotal => _otherCharges.fold(
    0.0,
    (runningTotal, charge) =>
        runningTotal + ((charge['amount'] as num?)?.toDouble() ?? 0.0),
  );

  int get _participantCount => widget.participants.isEmpty
      ? 1
      : widget.participants.length;

  double _shareForCharge(Map<String, dynamic> charge, double proportion) {
    final amount = ((charge['amount'] as num?)?.toDouble() ?? 0.0);
    final splitMethod = charge['split_method'] ?? charge['splitMethod'];
    if (splitMethod == 'equal') {
      return amount / _participantCount;
    }
    return amount * proportion;
  }

  @override
  void initState() {
    super.initState();
    _taxController = TextEditingController(text: widget.taxAmount.toString());
    _serviceController = TextEditingController(
      text: widget.serviceChargeAmount.toString(),
    );
    _tipController = TextEditingController(text: widget.tipAmount.toString());
    _discountController = TextEditingController(
      text: widget.discountAmount.toString(),
    );
    _deliveryFeeController = TextEditingController(
      text: widget.deliveryFeeAmount.toString(),
    );

    _calculateFinalShares();
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    _taxController.dispose();
    _serviceController.dispose();
    _tipController.dispose();
    _discountController.dispose();
    _deliveryFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadInterstitialAd() async {
    if (kIsWeb) return;

    // Check Premium Status
    final isPremium = await RevenueCatService.isPremium();
    if (isPremium) return;

    String adUnitId;
    if (kDebugMode) {
      adUnitId = Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    } else {
      adUnitId = Platform.isAndroid
          ? ApiKeys.adMobAndroidInterstitial
          : ApiKeys.adMobIosInterstitial;
    }

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) {
            debugPrint('InterstitialAd failed to load: $error');
          }
        },
      ),
    );
  }

  void _calculateFinalShares() {
    Map<String, double> shares = {};
    for (var p in widget.participants) {
      shares[p['id']] = 0.0;
    }

    List items = widget.receiptData['items'];
    for (int i = 0; i < items.length; i++) {
      double price = (items[i]['price'] as num).toDouble();
      int qty = (items[i]['qty'] as num?)?.toInt() ?? 1;

      if (qty > 1 &&
          widget.quantityAssignments.containsKey(i) &&
          widget.quantityAssignments[i]!.isNotEmpty) {
        double pricePerUnit = price;
        widget.quantityAssignments[i]!.forEach((uid, assignedQty) {
          if (shares.containsKey(uid)) {
            shares[uid] = (shares[uid]!) + (pricePerUnit * assignedQty);
          }
        });
      } else {
        List<String>? assignedIds = widget.itemAssignments[i];
        if (assignedIds != null && assignedIds.isNotEmpty) {
          double totalPrice = price * qty;
          double splitPrice = totalPrice / assignedIds.length;
          for (String uid in assignedIds) {
            if (shares.containsKey(uid)) {
              shares[uid] = (shares[uid]!) + splitPrice;
            }
          }
        }
      }
    }

    double totalItemsCost = shares.values.fold(
      0,
      (runningTotal, val) => runningTotal + val,
    );
    if (totalItemsCost == 0) totalItemsCost = 1;

    double tax = double.tryParse(_taxController.text) ?? 0.0;
    double service = double.tryParse(_serviceController.text) ?? 0.0;
    double tip = double.tryParse(_tipController.text) ?? 0.0;
    double discount = double.tryParse(_discountController.text) ?? 0.0;
    double delivery = double.tryParse(_deliveryFeeController.text) ?? 0.0;
    final proportionalOtherCharges = _otherCharges
        .where((charge) => charge['split_method'] != 'equal')
        .fold(
          0.0,
          (runningTotal, charge) =>
              runningTotal + ((charge['amount'] as num?)?.toDouble() ?? 0.0),
        );
    final equalOtherCharges = _otherCharges
        .where((charge) => charge['split_method'] == 'equal')
        .fold(
          0.0,
          (runningTotal, charge) =>
              runningTotal + ((charge['amount'] as num?)?.toDouble() ?? 0.0),
        );

    _finalShares = {};
    shares.forEach((uid, amount) {
      double userProportion = amount / totalItemsCost;
      _finalShares[uid] =
          amount +
          (tax * userProportion) +
          (service * userProportion) +
          (tip * userProportion) +
          (delivery / _participantCount) +
          (proportionalOtherCharges * userProportion) +
          (equalOtherCharges / _participantCount) -
          (discount * userProportion);
    });
  }

  Future<void> _createBill() async {
    setState(() => _isCreating = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    double tax = double.tryParse(_taxController.text) ?? 0.0;
    double service = double.tryParse(_serviceController.text) ?? 0.0;
    double tip = double.tryParse(_tipController.text) ?? 0.0;
    double discount = double.tryParse(_discountController.text) ?? 0.0;
    double delivery = double.tryParse(_deliveryFeeController.text) ?? 0.0;

    final billData = {
      'hostId': user.uid,
      'hostName': user.displayName,
      'storeName':
          widget.receiptData['restaurant_name'] ??
          widget.receiptData['storeName'],
      'date': FieldValue.serverTimestamp(),
      'total':
          _calculateTotalItemCost() +
          tax +
          service +
          tip +
          delivery +
          _otherChargesTotal -
          discount,
      'currencyCode': _currencyCode,
      'charges': {
        'taxAmount': tax,
        'serviceCharge': service,
        'tipAmount': tip,
        'discountAmount': discount,
        'deliveryFeeAmount':
            double.tryParse(_deliveryFeeController.text) ?? 0.0,
        'otherCharges': _otherCharges,
      },
      'items': widget.receiptData['items'].asMap().entries.map((entry) {
        int idx = entry.key;
        var item = entry.value;
        List<String> assigned = [];
        if (widget.quantityAssignments.containsKey(idx)) {
          assigned = widget.quantityAssignments[idx]!.keys.toList();
        } else {
          assigned = widget.itemAssignments[idx] ?? [];
        }

        List<String> realAssigned = assigned
            .map((id) => id == 'current_user' ? user.uid : id)
            .toList();
        return {
          'name': item['name'],
          'price': item['price'],
          'qty': item['qty'] ?? 1,
          'assignedTo': realAssigned,
        };
      }).toList(),
      'participants': widget.participants.map((p) {
        String realId = p['id'] == 'current_user' ? user.uid : p['id'];
        return {
          'id': realId,
          'name': p['name'],
          'photoUrl': p['photoUrl'],
          'share': _finalShares[p['id']] ?? 0.0,
          'isPaid': realId == user.uid,
          'phoneNumber': p['phoneNumber'],
          'status': realId == user.uid ? 'PAID' : 'PENDING',
        };
      }).toList(),
      'participants_uids': widget.participants
          .map((p) => p['id'] == 'current_user' ? user.uid : p['id'])
          .toList(),
    };

    // Fetch and add payment methods from user profile
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;

        // Check for new format (customPaymentMethods - list)
        if (userData['customPaymentMethods'] != null) {
          final List<dynamic> customMethods = userData['customPaymentMethods'];
          if (customMethods.isNotEmpty) {
            // Convert list to map for guest screen compatibility
            Map<String, String> methodsMap = {};
            for (var method in customMethods) {
              if (method is Map) {
                final name = method['name'] ?? '';
                final value = method['value'] ?? '';
                if (name.isNotEmpty && value.isNotEmpty) {
                  methodsMap[name] = value;
                }
              }
            }
            if (methodsMap.isNotEmpty) {
              billData['paymentMethods'] = methodsMap;
            }
          }
        }
        // Fallback to old format (paymentMethods - map)
        else if (userData['paymentMethods'] != null) {
          final Map<String, dynamic> oldMethods = userData['paymentMethods'];
          if (oldMethods.isNotEmpty) {
            billData['paymentMethods'] = oldMethods;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching payment methods: $e');
      }
      // Continue without payment methods - not critical
    }

    try {
      final billRef = await FirebaseFirestore.instance
          .collection('bills')
          .add(billData);
      final billId = billRef.id;

      // --- CLEANUP RESUMED BILL ---
      if (widget.oldBillIdToDelete != null) {
        try {
          await FirebaseFirestore.instance
              .collection('bills')
              .doc(widget.oldBillIdToDelete)
              .delete();
          if (kDebugMode) {
            debugPrint("Deleted old bill: ${widget.oldBillIdToDelete}");
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint("Error deleting old bill: $e");
          }
        }
      }

      if (widget.oldImageToDelete != null) {
        try {
          final file = File(widget.oldImageToDelete!);
          if (await file.exists()) {
            await file.delete();
            if (kDebugMode) {
              debugPrint("Deleted old local image: ${widget.oldImageToDelete}");
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint("Error deleting old local image: $e");
          }
        }
      }
      // -----------------------------

      List<String> appUserNames = [];
      for (var p in widget.participants) {
        if (!p['isGuest'] && p['id'] != user.uid) {
          appUserNames.add(p['name']);
          _notifyAppUser(
            p['id'],
            p['name'],
            widget.receiptData['restaurant_name'] ?? "a new bill",
            billId,
          );
        }
      }

      if (_isAdLoaded && _interstitialAd != null) {
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _navigateToSuccess(appUserNames, billId);
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _navigateToSuccess(appUserNames, billId);
          },
        );
        await _interstitialAd!.show();
      } else {
        _navigateToSuccess(appUserNames, billId);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving: $e")));
      setState(() => _isCreating = false);
    }
  }

  void _navigateToSuccess(List<String> appUserNames, String billId) {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SuccessScreen(
            storeName:
                widget.receiptData['restaurant_name'] ??
                widget.receiptData['storeName'] ??
                "Bill",
            billId: billId,
            notifiedUsers: appUserNames,
            currencyCode: _currencyCode,
            guestUsers: widget.participants
                .where((p) => p['isGuest'] == true)
                .map((p) {
                  final uid = p['id'];
                  return {
                    'name': p['name'],
                    'amount': _finalShares[uid] ?? 0.0,
                    'id': uid,
                  };
                })
                .toList(),
          ),
        ),
      );
    }
  }

  Future<void> _notifyAppUser(
    String uid,
    String name,
    String store,
    String billId,
  ) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final token = userDoc.data()?['fcmToken'];

      if (token != null) {
        await _notificationService.sendNotification(
          targetToken: token,
          targetUid: uid,
          title: "Split Bill: $store",
          body:
              "Your share is ${CurrencyUtils.format(_finalShares[uid] ?? 0.0, currencyCode: _currencyCode, decimalDigits: 1)}. Tap to view details.",
          data: {"type": "new_bill", "uid": uid, "billId": billId},
        );
      }
    } catch (e) {
      debugPrint("Error notifying user $name: $e");
    }
  }

  ImageProvider? _getAvatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final base64String = url.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  void _showUserBreakdown(Map<String, dynamic> participant) {
    final uid = participant['id'];
    List<Map<String, dynamic>> userItems = [];
    double itemTotal = 0.0;

    List items = widget.receiptData['items'];
    for (int i = 0; i < items.length; i++) {
      var item = items[i];
      double price = (item['price'] as num).toDouble();
      int totalQty = (item['qty'] as num?)?.toInt() ?? 1;
      if (totalQty > 1 &&
          widget.quantityAssignments.containsKey(i) &&
          widget.quantityAssignments[i]!.isNotEmpty) {
        if (widget.quantityAssignments[i]!.containsKey(uid)) {
          int assignedQty = widget.quantityAssignments[i]![uid]!;
          double userCost = price * assignedQty;
          itemTotal += userCost;
          userItems.add({
            'name': item['name'],
            'detail': "Got $assignedQty of $totalQty",
            'cost': userCost,
          });
        }
      } else if (widget.itemAssignments.containsKey(i)) {
        List<String> assigned = widget.itemAssignments[i]!;
        if (assigned.contains(uid)) {
          double totalPrice = price * totalQty;
          double splitPrice = totalPrice / assigned.length;
          itemTotal += splitPrice;
          userItems.add({
            'name': item['name'],
            'detail': assigned.length > 1
                ? "Split with ${assigned.length - 1} others"
                : "Full Item",
            'cost': splitPrice,
          });
        }
      }
    }

    double proportion = itemTotal / _calculateTotalItemCost();
    double finalShare = _finalShares[uid] ?? 0.0;
    double tax = double.tryParse(_taxController.text) ?? 0.0;
    double service = double.tryParse(_serviceController.text) ?? 0.0;
    double tip = double.tryParse(_tipController.text) ?? 0.0;
    double discount = double.tryParse(_discountController.text) ?? 0.0;
    double delivery = double.tryParse(_deliveryFeeController.text) ?? 0.0;
    final deliveryShare = delivery / _participantCount;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: participant['color'] ?? Colors.blue,
                  backgroundImage: _getAvatarImage(participant['photoUrl']),
                  child:
                      (_getAvatarImage(participant['photoUrl']) == null &&
                          participant['name'].isNotEmpty)
                      ? Text(
                          participant['name'][0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant['name'],
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Total Share: ${CurrencyUtils.format(finalShare, currencyCode: _currencyCode, decimalDigits: 1)}",
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 48),
            Text('item_breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ).tr(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: userItems.length,
                itemBuilder: (context, index) {
                  final uItem = userItems[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                uItem['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                uItem['detail'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyUtils.format(
                            (uItem['cost'] as double),
                            currencyCode: _currencyCode,
                            decimalDigits: 1,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 32),
            _buildAmountRow("Tax / VAT", tax * proportion),
            _buildAmountRow("Service Charge", service * proportion),
            _buildAmountRow("Tip", tip * proportion),
            _buildAmountRow("Delivery Fee", deliveryShare),
            ..._otherCharges
                .map(
                  (charge) => _buildAmountRow(
                    (charge['label'] ?? 'Other Charge').toString(),
                    _shareForCharge(charge, proportion),
                  ),
                )
                .whereType<Widget>(),
            _buildAmountRow(
              "Discount",
              discount * proportion,
              isNegative: true,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(
    String title,
    double amount, {
    bool isNegative = false,
  }) {
    if (amount == 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          Text(
            "${isNegative ? '-' : ''}${CurrencyUtils.format(amount.abs(), currencyCode: _currencyCode, decimalDigits: 1)}",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isNegative ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotalItemCost() {
    double total = 0.0;
    for (var item in widget.receiptData['items']) {
      total +=
          (item['price'] as num).toDouble() *
          ((item['qty'] as num?)?.toInt() ?? 1);
    }
    return total;
  }

  void _showRouletteModal() {
    if (widget.participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('add_participants_to_play_bill_roulette').tr(),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final selected = StreamController<int>();
    final participants = widget.participants;
    double tax = double.tryParse(_taxController.text) ?? 0.0;
    double service = double.tryParse(_serviceController.text) ?? 0.0;
    double tip = double.tryParse(_tipController.text) ?? 0.0;
    double discount = double.tryParse(_discountController.text) ?? 0.0;
    double delivery = double.tryParse(_deliveryFeeController.text) ?? 0.0;
    final totalBill =
        _calculateTotalItemCost() +
        tax +
        service +
        tip +
        delivery +
        _otherChargesTotal -
        discount;

    bool isSpinning = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('bill_roulette_2',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ).tr(),
                const SizedBox(height: 12),
                Text('one_lucky_person_pays_the_whole_bill',
                  style: TextStyle(color: Colors.grey[600]),
                ).tr(),
                const SizedBox(height: 24),
                Expanded(
                  child: FortuneWheel(
                    selected: selected.stream,
                    animateFirst: false,
                    items: [
                      for (int i = 0; i < participants.length; i++)
                        FortuneItem(
                          child: Text(
                            participants[i]['name'],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FortuneItemStyle(
                            color: participants[i]['color'] ?? Colors.blue,
                            borderColor: Colors.white,
                            borderWidth: 2,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isSpinning
                      ? null
                      : () async {
                          setModalState(() => isSpinning = true);
                          final int randomIndex = Fortune.randomInt(
                            0,
                            participants.length,
                          );
                          selected.add(randomIndex);
                          await Future.delayed(const Duration(seconds: 5));
                          if (context.mounted) {
                            Navigator.pop(context);
                            _showWinnerDialog(
                              participants[randomIndex],
                              totalBill,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    minimumSize: const Size(double.infinity, 60),
                    elevation: 0,
                  ),
                  child: Text(
                    isSpinning ? "SPINNING..." : "SPIN THE WHEEL!",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      selected.close();
    });
  }

  void _showWinnerDialog(Map<String, dynamic> winner, double totalBill) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/confetti.json',
              height: 150,
              repeat: true,
            ),
            Text('we_have_a_winner',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: Colors.redAccent,
              ),
            ).tr(),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 50,
              backgroundColor: winner['color'] ?? Colors.blue,
              backgroundImage: _getAvatarImage(winner['photoUrl']),
              child:
                  (_getAvatarImage(winner['photoUrl']) == null &&
                      winner['name'].isNotEmpty)
                  ? Text(
                      winner['name'][0],
                      style: const TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              winner['name'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "The universe has spoken. ${winner['name']} gets the honor of paying the whole bill! 😂",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              "Total: ${CurrencyUtils.format(totalBill, currencyCode: _currencyCode, decimalDigits: 1)}",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('mercy_shown_bill_splitting_remains_as_is',
                          ).tr(),
                        ),
                      );
                    },
                    child: Text('pardon_them',
                      style: TextStyle(color: Colors.grey),
                    ).tr(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _applyRouletteResult(winner['id']);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text('assign_bill').tr(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyRouletteResult(String winnerId) {
    setState(() {
      _rouletteWinnerId = winnerId;
      double tax = double.tryParse(_taxController.text) ?? 0.0;
      double service = double.tryParse(_serviceController.text) ?? 0.0;
      double tip = double.tryParse(_tipController.text) ?? 0.0;
      double discount = double.tryParse(_discountController.text) ?? 0.0;
      double delivery = double.tryParse(_deliveryFeeController.text) ?? 0.0;
      double grandTotal =
          _calculateTotalItemCost() +
          tax +
          service +
          tip +
          delivery +
          _otherChargesTotal -
          discount;

      _finalShares.forEach((id, _) {
        _finalShares[id] = (id == winnerId) ? grandTotal : 0.0;
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('bill_successfully_assigned_to_the_loser').tr(),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double subTotal = _calculateTotalItemCost();
    double tax = double.tryParse(_taxController.text) ?? 0.0;
    double service = double.tryParse(_serviceController.text) ?? 0.0;
    double tip = double.tryParse(_tipController.text) ?? 0.0;
    double discount = double.tryParse(_discountController.text) ?? 0.0;
    double delivery = double.tryParse(_deliveryFeeController.text) ?? 0.0;
    double grandTotal =
        subTotal + tax + service + tip + delivery + _otherChargesTotal - discount;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppHeader(
        title: 'split_summary'.tr(),
        trailing: IconButton(
          icon: Icon(
            _isEditing ? Icons.save_rounded : Icons.edit_rounded,
            color: const Color(0xFF00B365),
          ),
          onPressed: () {
            setState(() {
              if (_isEditing) {
                _calculateFinalShares();
                _isEditing = false;
                HapticFeedback.mediumImpact();
              } else {
                _isEditing = true;
              }
            });
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  BillSummaryRow(
                    label: "Grand Total",
                    amount: grandTotal,
                    isBold: true,
                    fontSize: 26,
                    isPrimary: true,
                    currency: _currencyCode,
                  ),
                  const Divider(height: 40),
                  BillSummaryRow(
                    label: "Sub Total",
                    amount: subTotal,
                    currency: _currencyCode,
                  ),
                  const SizedBox(height: 12),
                  if (_isEditing) ...[
                    _buildEditChargeField("Tax", _taxController),
                    _buildEditChargeField("Service Charge", _serviceController),
                    _buildEditChargeField("Tip", _tipController),
                    _buildEditChargeField("Discount", _discountController),
                    _buildEditChargeField(
                      "Delivery Fee",
                      _deliveryFeeController,
                    ),
                  ] else ...[
                    BillSummaryRow(
                      label: "Tax",
                      amount: tax,
                      currency: _currencyCode,
                    ),
                    const SizedBox(height: 12),
                    BillSummaryRow(
                      label: "Service Charge",
                      amount: service,
                      currency: _currencyCode,
                    ),
                    const SizedBox(height: 12),
                    BillSummaryRow(
                      label: "Tip",
                      amount: tip,
                      currency: _currencyCode,
                    ),
                    const SizedBox(height: 12),
                    BillSummaryRow(
                      label: "Discount",
                      amount: discount,
                      currency: _currencyCode,
                    ),
                    const SizedBox(height: 12),
                    BillSummaryRow(
                      label: "Delivery Fee",
                      amount: delivery,
                      currency: _currencyCode,
                    ),
                    ..._otherCharges.expand((charge) => [
                      const SizedBox(height: 12),
                      BillSummaryRow(
                        label: (charge['label'] ?? 'Other Charge').toString(),
                        amount: ((charge['amount'] as num?)?.toDouble() ?? 0.0),
                        currency: _currencyCode,
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showRouletteModal,
                icon: const Icon(Icons.casino_rounded, color: Colors.redAccent),
                label: Text('bill_roulette',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ).tr(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.participants.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = widget.participants[index];
                return ParticipantShareCard(
                  participant: p,
                  share: _finalShares[p['id']] ?? 0.0,
                  isWinner: _rouletteWinnerId == p['id'],
                  onTap: () => _showUserBreakdown(p),
                  getAvatarImage: _getAvatarImage,
                  currency: _currencyCode,
                );
              },
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          height: 60,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isCreating ? null : _createBill,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B365),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: _isCreating
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('create_bill',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ).tr(),
          ),
        ),
      ),
    );
  }

  Widget _buildEditChargeField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 16)),
          SizedBox(
            width: 100,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              onChanged: (_) => setState(() => _calculateFinalShares()),
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                suffixText: " $_currencyCode",
              ),
            ),
          ),
        ],
      ),
    );
  }
}
