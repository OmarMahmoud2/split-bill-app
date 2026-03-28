import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/utils/currency_utils.dart';

class BillItemsList extends StatelessWidget {
  final List<dynamic> items;
  final Map<int, List<String>> itemAssignments;
  final List<Map<String, dynamic>> participants;
  final Function(int) onItemTap;
  final String currencyCode;

  const BillItemsList({
    super.key,
    required this.items,
    required this.itemAssignments,
    required this.participants,
    required this.onItemTap,
    this.currencyCode = 'USD',
  });

  ImageProvider? _getAvatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        int qty = (item['qty'] as num? ?? 1).toInt();
        double price = (item['price'] as num).toDouble();
        double total = price * qty;
        final assignedIds = itemAssignments[index] ?? [];

        return GestureDetector(
          onTap: () => onItemTap(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: assignedIds.isNotEmpty
                  ? Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                      width: 2,
                    )
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Lottie.asset(
                    'assets/animations/food.json',
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) =>
                        const Icon(Icons.fastfood, color: Colors.orange),
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
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            "x$qty",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyUtils.format(
                              total,
                              currencyCode: currencyCode,
                              decimalDigits: 1,
                            ),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildAssignmentIndicator(assignedIds),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssignmentIndicator(List<String> userIds) {
    if (userIds.isEmpty) {
      return Icon(
        Icons.add_circle_outline_rounded,
        color: Colors.grey[300],
        size: 28,
      );
    }

    return SizedBox(
      height: 36,
      width: 80,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          for (int i = 0; i < (userIds.length > 3 ? 3 : userIds.length); i++)
            Positioned(
              right: i * 20.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 2),
                  ],
                ),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      participants.firstWhere(
                        (e) => e['id'] == userIds[i],
                        orElse: () => {'color': Colors.grey},
                      )['color'] ??
                      Colors.blue,
                  backgroundImage: _getAvatarImage(
                    participants.firstWhere(
                      (e) => e['id'] == userIds[i],
                      orElse: () => {},
                    )['photoUrl'],
                  ),
                  child:
                      _getAvatarImage(
                            participants.firstWhere(
                              (e) => e['id'] == userIds[i],
                              orElse: () => {},
                            )['photoUrl'],
                          ) ==
                          null
                      ? Text(
                          participants.firstWhere(
                            (e) => e['id'] == userIds[i],
                            orElse: () => {'name': '?'},
                          )['name'][0],
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
