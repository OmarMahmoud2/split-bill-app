import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/utils/currency_utils.dart';

class BillSummaryWidget extends StatelessWidget {
  final double total;
  final double collected;
  final String title;
  final dynamic date;
  final String? hostName;
  final String currencyCode;

  const BillSummaryWidget({
    super.key,
    required this.total,
    required this.collected,
    required this.title,
    this.date,
    this.hostName,
    this.currencyCode = 'USD',
  });

  String _formatDate(dynamic date) {
    if (date == null) return "Unknown date";
    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else {
      return "Processing...";
    }
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final double left = total - collected;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Upper Info Card
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: primaryColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            _formatDate(date),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hostName != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, thickness: 0.5),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.person_pin_rounded,
                        size: 18,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Created by ",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      Text(
                        hostName!,
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Metrics Row
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              children: [
                _buildMetric(
                  context,
                  "Collected",
                  CurrencyUtils.format(collected, currencyCode: currencyCode),
                  Colors.green,
                  Icons.check_circle_rounded,
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
                _buildMetric(
                  context,
                  "Left",
                  CurrencyUtils.format(left, currencyCode: currencyCode),
                  Colors.orange[700]!,
                  Icons.hourglass_bottom_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
