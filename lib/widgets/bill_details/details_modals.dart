import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

class BillDetailsModals {
  static String _currencyCode(Map<String, dynamic> billData) =>
      (billData['currencyCode'] ?? billData['currency_code'] ?? 'USD')
          .toString();

  static List<Map<String, dynamic>> _otherCharges(Map<String, dynamic> billData) {
    final charges = billData['charges'] as Map<String, dynamic>? ?? {};
    return List<Map<String, dynamic>>.from(charges['otherCharges'] ?? const []);
  }

  static void showFullBillDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final List<dynamic> items = data['items'] ?? [];
    final Map<String, dynamic> charges = data['charges'] ?? {};
    final String storeName = data['storeName'] ?? 'bill_details'.tr();
    final String currencyCode = _currencyCode(data);

    PremiumBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.76,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('bill_breakdown',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.blue[800],
                            letterSpacing: 2.0,
                          ),
                        ).tr(),
                        const SizedBox(height: 4),
                        Text(
                          storeName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 45,
                      height: 45,
                      child: Lottie.asset('assets/animations/food.json'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final List? assignedTo = item['assignedTo'] as List?;
                  final int splitCount = assignedTo?.length ?? 1;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey[100]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          child: Text(
                            'quantity_suffix'.tr(
                              namedArgs: {'qty': (item['qty'] ?? 1).toString()},
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.blue[900],
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] ?? 'unknown_item'.tr(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              if (splitCount > 1)
                                Text(
                                  'split_between_people'.tr(
                                    namedArgs: {'count': splitCount.toString()},
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyUtils.format(
                                ((item['price'] as num? ?? 0.0) *
                                        (item['qty'] as num? ?? 1))
                                    .toDouble(),
                                currencyCode: currencyCode,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _buildChargesFooter(
              context,
              charges,
              (data['total'] as num? ?? 0.0).toDouble(),
              currencyCode,
              _otherCharges(data),
            ),
          ],
        ),
      ),
    );
  }

  static void showUserShareDetails(
    BuildContext context,
    Map<String, dynamic> participant,
    Map<String, dynamic> billData,
  ) {
    final List<dynamic> allItems = billData['items'] ?? [];
    final Map<String, dynamic> charges = billData['charges'] ?? {};
    final String uid = participant['id'];
    final String currencyCode = _currencyCode(billData);

    final userItems = allItems.where((item) {
      final assigned = item['assignedTo'] as List?;
      return assigned?.contains(uid) ?? false;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[800]!.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.blue[800],
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'participant_details_title'.tr(
                    namedArgs: {'name': participant['name'].toString()},
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text('detailed_items_and_proportions',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ).tr(),
                const SizedBox(height: 24),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: userItems.length,
                    itemBuilder: (context, index) {
                      final item = userItems[index];
                      final num assignedCount =
                          (item['assignedTo'] as List).length;
                      final double userPrice =
                          ((item['price'] as num) * (item['qty'] as num)) /
                          assignedCount;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.blue[300],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'item_assignment_ratio'.tr(
                                  namedArgs: {
                                    'name': item['name'].toString(),
                                    'count': assignedCount.toString(),
                                  },
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              CurrencyUtils.format(
                                userPrice,
                                currencyCode: currencyCode,
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, thickness: 1),
                ),
                _buildSimpleCharges(
                  participant,
                  charges,
                  billData,
                  currencyCode,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[600]!.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.green[600]!.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('my_total',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.green[800],
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ).tr(),
                      Text(
                        CurrencyUtils.format(
                          (participant['share'] as num).toDouble(),
                          currencyCode: currencyCode,
                        ),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[900],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: Text('got_it_3',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ).tr(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildChargesFooter(
    BuildContext context,
    Map<String, dynamic> charges,
    double total,
    String currencyCode,
    List<Map<String, dynamic>> otherCharges,
  ) {
    final tax = (charges['taxAmount'] as num? ?? 0.0).toDouble();
    final service = (charges['serviceCharge'] as num? ?? 0.0).toDouble();
    final tip = (charges['tipAmount'] as num? ?? 0.0).toDouble();
    final discount = (charges['discountAmount'] as num? ?? 0.0).toDouble();
    final delivery = (charges['deliveryFeeAmount'] as num? ?? 0.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (tax > 0)
              _buildChargeRow('receipt_tax'.tr(), tax, currencyCode: currencyCode),
            if (service > 0)
              _buildChargeRow(
                'receipt_service_charge'.tr(),
                service,
                currencyCode: currencyCode,
              ),
            if (tip > 0)
              _buildChargeRow('receipt_tip'.tr(), tip, currencyCode: currencyCode),
            if (delivery > 0)
              _buildChargeRow(
                'receipt_delivery_fee'.tr(),
                delivery,
                currencyCode: currencyCode,
              ),
            ...otherCharges.map(
              (charge) => _buildChargeRow(
                (charge['label'] ?? 'receipt_other_charge_label'.tr()).toString(),
                ((charge['amount'] as num?)?.toDouble() ?? 0.0),
                currencyCode: currencyCode,
              ),
            ),
            if (discount > 0)
              _buildChargeRow(
                'receipt_discount'.tr(),
                -discount,
                isDiscount: true,
                currencyCode: currencyCode,
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('grand_total',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ).tr(),
                Text(
                  CurrencyUtils.format(total, currencyCode: currencyCode),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSimpleCharges(
    Map<String, dynamic> participant,
    Map<String, dynamic> charges,
    Map<String, dynamic> billData,
    String currencyCode,
  ) {
    final items = billData['items'] as List? ?? const [];
    final participants = billData['participants'] as List? ?? const [];
    final participantCount = participants.isEmpty ? 1 : participants.length;
    final otherCharges = _otherCharges(billData);
    final uid = participant['id'];

    final double totalItems = items.fold(0.0, (sum, item) {
      return sum + ((item['price'] as num) * (item['qty'] as num)).toDouble();
    });

    if (totalItems == 0) return const SizedBox.shrink();

    double userItemsTotal = 0.0;
    for (final item in items) {
      final assigned = item['assignedTo'] as List? ?? const [];
      if (assigned.contains(uid) && assigned.isNotEmpty) {
        final itemTotal =
            ((item['price'] as num) * (item['qty'] as num? ?? 1)).toDouble();
        userItemsTotal += itemTotal / assigned.length;
      }
    }

    final double userProportion = userItemsTotal / totalItems;

    final tax =
        (charges['taxAmount'] as num? ?? 0.0).toDouble() * userProportion;
    final service =
        (charges['serviceCharge'] as num? ?? 0.0).toDouble() * userProportion;
    final tip =
        (charges['tipAmount'] as num? ?? 0.0).toDouble() * userProportion;
    final delivery =
        (charges['deliveryFeeAmount'] as num? ?? 0.0).toDouble() /
        participantCount;
    final discount =
        (charges['discountAmount'] as num? ?? 0.0).toDouble() * userProportion;

    return Column(
      children: [
        if (tax > 0)
          _buildChargeRow(
            'tax_portion'.tr(),
            tax,
            small: true,
            currencyCode: currencyCode,
          ),
        if (service > 0)
          _buildChargeRow(
            'service_portion'.tr(),
            service,
            small: true,
            currencyCode: currencyCode,
          ),
        if (tip > 0)
          _buildChargeRow(
            'tip_portion'.tr(),
            tip,
            small: true,
            currencyCode: currencyCode,
          ),
        if (delivery > 0)
          _buildChargeRow(
            'delivery_portion'.tr(),
            delivery,
            small: true,
            currencyCode: currencyCode,
          ),
        ...otherCharges
            .map((charge) {
              final amount = ((charge['amount'] as num?)?.toDouble() ?? 0.0);
              final splitMethod = charge['splitMethod'] ?? charge['split_method'];
              final share = splitMethod == 'equal'
                  ? amount / participantCount
                  : amount * userProportion;
              if (share <= 0) {
                return null;
              }
              return _buildChargeRow(
                'charge_portion'.tr(
                  namedArgs: {
                    'label': (charge['label'] ?? 'receipt_other_charge_label'.tr()).toString(),
                  },
                ),
                share,
                small: true,
                currencyCode: currencyCode,
              );
            })
            .whereType<Widget>(),
        if (discount > 0)
          _buildChargeRow(
            'discount_portion'.tr(),
            -discount,
            small: true,
            isDiscount: true,
            currencyCode: currencyCode,
          ),
      ],
    );
  }

  static Widget _buildChargeRow(
    String label,
    double amount, {
    bool isDiscount = false,
    bool small = false,
    String currencyCode = 'USD',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: small ? 11 : 13,
            ),
          ),
          Text(
            "${amount > 0 ? '+' : ''}${CurrencyUtils.format(amount.abs(), currencyCode: currencyCode)}",
            style: TextStyle(
              color: isDiscount ? Colors.red : Colors.grey[800],
              fontWeight: small ? FontWeight.w500 : FontWeight.bold,
              fontSize: small ? 11 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
