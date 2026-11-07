import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_motion.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_spacing.dart';
import 'package:split_bill_app/theme/app_typography.dart';
import 'package:split_bill_app/theme/app_icons.dart';

/// The ink (navy in dark mode) "Offline. Changes will sync when you're back." banner from the
/// v3 states mockup. Animates its height in and out with [visible]; the
/// connectivity source is up to the screen.
///
/// ```dart
/// OfflineBanner(visible: !isOnline)
/// OfflineBanner(visible: true, message: 'offline_bills_pending'.tr(
///     namedArgs: {'count': '2'}))
/// ```
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.visible = true,
    this.message,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
  });

  final bool visible;

  /// Defaults to `feedback_offline_banner`.
  final String? message;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final duration = AppMotion.durationFor(context, AppMotion.slow);
    final banner = Padding(
      padding: margin,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.toast,
            borderRadius: BorderRadius.circular(18),
            border: p.isDark ? Border.all(color: p.border) : null,
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.wifiOff,
                size: 18,
                color: (p.isDark ? p : AppPalette.dark).coral,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message ?? 'feedback_offline_banner'.tr(),
                  style: AppTypography.titleSmall.copyWith(
                    color: p.onToast,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppMotion.emphasizedDecelerate,
      switchOutCurve: AppMotion.emphasizedAccelerate,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          alignment: AlignmentDirectional.topCenter,
          child: child,
        ),
      ),
      child: visible
          ? KeyedSubtree(key: const ValueKey('offline'), child: banner)
          : const SizedBox(key: ValueKey('online'), width: double.infinity),
    );
  }
}
