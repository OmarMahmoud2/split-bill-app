import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class GuestHeader extends StatelessWidget {
  final String storeName;
  final bool isCompact;

  const GuestHeader({
    super.key,
    required this.storeName,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 40), // Spacer for back button
            Expanded(
              child: Column(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 32,
                    color: Colors.blue[800],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    storeName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 40), // Balance
          ],
        ),
      );
    }

    // Large Header (Selector View) - TILE STYLE
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. App Logo & Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/logo.png', height: 40),
                    const SizedBox(width: 12),
                    Text('splitbill',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue[800],
                        letterSpacing: -0.5,
                      ),
                    ).tr(),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(height: 1, color: Colors.grey[200]),
                const SizedBox(height: 24),

                // 2. Store Name
                Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // 3. Subtitle Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('guest_payment_portal',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ).tr(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
