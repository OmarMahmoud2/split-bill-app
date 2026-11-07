import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_icons.dart';

class AssignmentMethodSheet extends StatelessWidget {
  final VoidCallback onVoiceCommand;
  final VoidCallback onManualAssignment;

  const AssignmentMethodSheet({
    super.key,
    required this.onVoiceCommand,
    required this.onManualAssignment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'how_to_assign_items',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ).tr(),
        const SizedBox(height: 24),
        _buildMethodOption(
          context,
          icon: AppIcons.mic,
          title: 'voice_command'.tr(),
          subtitle: 'just_say_who_ate_what_cost_1_credit'.tr(),
          color: context.palette.accent,
          onTap: () {
            Navigator.pop(context);
            onVoiceCommand();
          },
        ),
        const SizedBox(height: 16),
        _buildMethodOption(
          context,
          icon: AppIcons.tap,
          title: 'manual_assignment'.tr(),
          subtitle: 'tap_to_assign_items_manually_free'.tr(),
          color: context.palette.textPrimary,
          onTap: () {
            Navigator.pop(context);
            onManualAssignment();
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMethodOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRight,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
