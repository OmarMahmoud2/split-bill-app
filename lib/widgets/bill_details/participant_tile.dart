import 'package:flutter/material.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:easy_localization/easy_localization.dart';

class ParticipantTile extends StatelessWidget {
  final Map<String, dynamic> participant;
  final double totalBill;
  final bool isHost;
  final VoidCallback onTap;
  final String currencyCode;

  const ParticipantTile({
    super.key,
    required this.participant,
    required this.totalBill,
    required this.isHost,
    required this.onTap,
    this.currencyCode = 'USD',
  });

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return "?";
    List<String> parts = name.trim().split(" ");
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final double share = (participant['share'] as num? ?? 0.0).toDouble();
    // In actual use, percentage should be passed down or calculated from normalized shares
    // For now we use the local calculation, but will fix the logic in the parent screen.
    final double percentage = totalBill > 0 ? (share / totalBill) : 0;
    final String status = participant['status'] ?? 'PENDING';
    final bool isAppUser =
        participant['id'] != null && !participant['id'].startsWith('guest_');
    final String? photoUrl = participant['photoUrl'];

    Color statusColor;
    Color tileBgColor = Colors.white;

    switch (status) {
      case 'PAID':
        statusColor = const Color(0xFF2E7D32); // Deeper Green
        tileBgColor = const Color(0xFFF1F8E9); // Very subtle green tint
        break;
      case 'REVIEW':
        statusColor = Colors.orange[800]!;
        break;
      default:
        statusColor = const Color(0xFF1976D2); // Material Blue
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tileBgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with Circular Progress
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: CircularProgressIndicator(
                        value: percentage,
                        strokeWidth: 3.5,
                        backgroundColor: Colors.grey[100],
                        valueColor: AlwaysStoppedAnimation(statusColor),
                      ),
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: ImageUtils.getAvatarImage(photoUrl),
                      child: photoUrl == null || photoUrl.isEmpty
                          ? Text(
                              _getInitials(participant['name']),
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Name and Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              participant['name'] ?? "Guest",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isHost) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[600]!.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('host',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blue[700],
                                  letterSpacing: 0.5,
                                ),
                              ).tr(),
                            ),
                          ],
                          if (isAppUser && !isHost) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: Colors.amber[800],
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${(percentage * 100).toStringAsFixed(1)}% of total",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Price and Status Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyUtils.format(share, currencyCode: currencyCode),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
