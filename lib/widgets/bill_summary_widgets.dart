import 'package:flutter/material.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:easy_localization/easy_localization.dart';

class BillSummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final double fontSize;
  final bool isPrimary;
  final String currency;

  const BillSummaryRow({
    super.key,
    required this.label,
    required this.amount,
    this.isBold = false,
    this.fontSize = 16,
    this.isPrimary = false,
    this.currency = "USD",
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isPrimary ? Colors.black : Colors.grey[700],
          ),
        ),
        Text(
          CurrencyUtils.format(
            amount,
            currencyCode: currency,
            decimalDigits: 1,
          ),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isPrimary
                ? Theme.of(context).colorScheme.primary
                : Colors.black,
          ),
        ),
      ],
    );
  }
}

class ParticipantShareCard extends StatelessWidget {
  final Map<String, dynamic> participant;
  final double share;
  final bool isWinner;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final ImageProvider? Function(String?) getAvatarImage;
  final String currency;

  const ParticipantShareCard({
    super.key,
    required this.participant,
    required this.share,
    required this.isWinner,
    required this.onTap,
    this.onEdit,
    required this.getAvatarImage,
    this.currency = "USD",
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: participant['color'] ?? Colors.blue,
                backgroundImage: getAvatarImage(participant['photoUrl']),
                child:
                    (getAvatarImage(participant['photoUrl']) == null &&
                        (participant['name'] as String).isNotEmpty)
                    ? Text(
                        participant['name'][0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            participant['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isWinner) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('big_loser',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ).tr(),
                          ),
                        ],
                      ],
                    ),
                    Text('view_details',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ).tr(),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyUtils.format(
                      share,
                      currencyCode: currency,
                      decimalDigits: 1,
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (onEdit != null)
                    GestureDetector(
                      onTap: onEdit,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'common_edit',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ).tr(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
