import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class AddMembersSheet extends StatelessWidget {
  final VoidCallback onScanQR;
  final VoidCallback onPickContacts;
  final VoidCallback? onPickGroups;

  const AddMembersSheet({
    super.key,
    required this.onScanQR,
    required this.onPickContacts,
    this.onPickGroups,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'add_people',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ).tr(),
              const SizedBox(height: 8),
              Text(
                'invite_friends_or_select_groups_to_start_splitting_the_bill',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ).tr(),
            ],
          ),
        ),

        const SizedBox(height: 32),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAddOption(
              context,
              Icons.qr_code_scanner_rounded,
              'scan_qr'.tr(),
              const Color(0xFF007AFF),
              onScanQR,
            ),
            _buildAddOption(
              context,
              Icons.contacts_rounded,
              'contacts'.tr(),
              const Color(0xFF5856D6),
              onPickContacts,
            ),
            if (onPickGroups != null)
              _buildAddOption(
                context,
                Icons.groups_rounded,
                'groups'.tr(),
                const Color(0xFFFF9500),
                onPickGroups!,
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAddOption(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
