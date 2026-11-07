import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_spacing.dart';
import 'package:split_bill_app/theme/app_typography.dart';
import 'package:split_bill_app/theme/app_icons.dart';

enum ErrorStateVariant {
  /// Centered in the available space (whole screen or a tab body).
  fullScreen,

  /// A hairline card that sits inside a list or form.
  inline,
}

/// A plain-language error with a way forward.
///
/// Say what happened and what to do, in the user's words ("The photo is too
/// dark. Your credit was refunded."), never an exception string.
///
/// ```dart
/// ErrorState(onRetry: _load) // generic title/message, "Try again"
/// ErrorState.inline(
///   title: 'scan_failed_title'.tr(), message: 'scan_failed_dark'.tr(),
///   retryLabel: 'retake_photo'.tr(), onRetry: _retake,
///   secondaryLabel: 'type_it_in'.tr(), onSecondary: _manual)
/// ErrorState.offline(onRetry: _load)
/// ```
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
    this.secondaryLabel,
    this.onSecondary,
    this.icon = AppIcons.error,
    this.variant = ErrorStateVariant.fullScreen,
  });

  const ErrorState.inline({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.retryLabel,
    this.secondaryLabel,
    this.onSecondary,
    this.icon = AppIcons.error,
  }) : variant = ErrorStateVariant.inline;

  /// Offline preset: "You're offline" with the sync reassurance.
  factory ErrorState.offline({
    Key? key,
    VoidCallback? onRetry,
    ErrorStateVariant variant = ErrorStateVariant.fullScreen,
  }) => ErrorState(
    key: key,
    title: 'feedback_offline_title'.tr(),
    message: 'feedback_offline_message'.tr(),
    onRetry: onRetry,
    icon: AppIcons.wifiOff,
    variant: variant,
  );

  /// Defaults to `feedback_error_title`.
  final String? title;

  /// Defaults to `feedback_error_message`.
  final String? message;

  /// Primary action; hidden when null.
  final VoidCallback? onRetry;

  /// Defaults to `feedback_try_again`.
  final String? retryLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData icon;
  final ErrorStateVariant variant;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final titleText = title ?? 'feedback_error_title'.tr();
    final messageText = message ?? 'feedback_error_message'.tr();
    final hasSecondary = secondaryLabel != null && onSecondary != null;
    final retry = onRetry == null
        ? null
        : FilledButton(
            onPressed: onRetry,
            child: Text(retryLabel ?? 'feedback_try_again'.tr()),
          );
    final secondary = hasSecondary
        ? OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!))
        : null;

    if (variant == ErrorStateVariant.inline) {
      final small = ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, AppSpacing.buttonMd)),
        textStyle: WidgetStatePropertyAll(AppTypography.labelMedium),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      );
      return Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titleText,
                style: AppTypography.titleMedium.copyWith(
                  fontSize: 16,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                messageText,
                style: AppTypography.bodyMedium.copyWith(
                  color: p.textSecondary,
                ),
              ),
              if (retry != null || secondary != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (retry != null)
                      Expanded(
                        child: FilledButton(
                          onPressed: onRetry,
                          style: small,
                          child: Text(retryLabel ?? 'feedback_try_again'.tr()),
                        ),
                      ),
                    if (retry != null && secondary != null)
                      const SizedBox(width: AppSpacing.sm),
                    if (secondary != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onSecondary,
                          style: small,
                          child: Text(secondaryLabel!),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      liveRegion: true,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    // Offline is a wait, not a failure: sky, not red.
                    color: icon == AppIcons.wifiOff ? p.skySoft : p.errorSoft,
                    borderRadius: AppRadii.cardRadius,
                  ),
                  child: Icon(
                    icon,
                    size: 30,
                    color: icon == AppIcons.wifiOff ? p.sky : p.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  titleText,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMedium.copyWith(
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  messageText,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (retry != null)
                  SizedBox(width: double.infinity, child: retry),
                if (secondary != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(width: double.infinity, child: secondary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
