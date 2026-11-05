import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/theme/app_palette.dart';

class CreateBillSheet extends StatelessWidget {
  const CreateBillSheet({
    super.key,
    required this.onScanTap,
    required this.onManualTap,
  });

  final VoidCallback onScanTap;
  final VoidCallback onManualTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'start_a_new_bill',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ).tr(),
        const SizedBox(height: 32),

        _CreateBillOption(
          icon: Icons.qr_code_scanner_rounded,
          title: 'scan_receipt'.tr(),
          subtitle:
              'best_when_you_already_have_the_bill_photo_or_want_camera_import'
                  .tr(),
          gradientColors: [const Color(0xFF00B4D8), const Color(0xFF0077B6)],
          iconBgColor: p.tint(const Color(0xFFE0F2F1), Colors.teal),
          onTap: onScanTap,
        ),
        const SizedBox(height: 16),
        _CreateBillOption(
          icon: Icons.edit_note_rounded,
          title: 'enter_manually'.tr(),
          subtitle:
              'build_the_receipt_yourself_then_continue_to_split_and_add_people'
                  .tr(),
          gradientColors: [p.primary, p.primaryStrong],
          iconBgColor: p.primarySoft,
          onTap: onManualTap,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _CreateBillOption extends StatelessWidget {
  const _CreateBillOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.iconBgColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final Color iconBgColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.isDark ? Colors.white.withValues(alpha: 0.05) : p.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.1)
                : p.textTertiary.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: p.shadow.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors
                      .map((c) => c.withValues(alpha: 0.15))
                      .toList(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: gradientColors[0], size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
