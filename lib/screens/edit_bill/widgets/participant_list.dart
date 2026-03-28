import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:split_bill_app/utils/currency_utils.dart';

class ParticipantList extends StatelessWidget {
  final List<Map<String, dynamic>> participants;
  final Map<String, double> currentShares;
  final Function(Map<String, dynamic>) onParticipantTap;
  final String currencyCode;

  const ParticipantList({
    super.key,
    required this.participants,
    required this.currentShares,
    required this.onParticipantTap,
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
    return Container(
      height: 155,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: participants.length,
        separatorBuilder: (c, i) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final p = participants[index];
          final isHost = p['isHost'] == true;
          final share = currentShares[p['id']] ?? 0.0;
          final String status = p['status'] ?? 'PENDING';

          return GestureDetector(
            onTap: () => onParticipantTap(p),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: p['color'] ?? Colors.blue,
                          width: 2,
                        ),
                        boxShadow: isHost
                            ? [
                                BoxShadow(
                                  color: (p['color'] ?? Colors.blue)
                                      .withValues(alpha: 0.6),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: (p['color'] ?? Colors.blue)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        backgroundImage: _getAvatarImage(p['photoUrl']),
                        child: _getAvatarImage(p['photoUrl']) == null
                            ? Text(
                                p['name'][0].toUpperCase(),
                                style: TextStyle(
                                  color: p['color'] ?? Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                    ),
                    if (status == 'PAID')
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  p['name'].split(" ")[0],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  CurrencyUtils.format(
                    share,
                    currencyCode: currencyCode,
                    decimalDigits: 1,
                  ),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
