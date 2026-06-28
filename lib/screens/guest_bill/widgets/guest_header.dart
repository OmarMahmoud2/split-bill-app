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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    if (isCompact) {
      return Container(
        padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 44),
            Expanded(
              child: Column(
                children: [
                  Image.asset('assets/logo.png', height: 30),
                  const SizedBox(height: 8),
                  Text(
                    storeName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                      letterSpacing: 0,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 44),
          ],
        ),
      );
    }

    // Large header used by the selector view.
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
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
                  Text(
                    'splitbill',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                      letterSpacing: 0,
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
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  height: 1.1,
                  letterSpacing: 0,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // 3. Subtitle Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'guest_payment_portal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
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
    );
  }
}
