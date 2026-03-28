import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// Reusable error state widget with Lottie animation
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    super.key,
    this.title = 'Oops! Something went wrong',
    required this.message,
    this.actionLabel = 'Try Again',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Animation
            Lottie.asset(
              'assets/animations/error.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to static icon
                return Container(
                  padding: AppSpacing.allXxl,
                  decoration: BoxDecoration(
                    color: AppColors.errorLight.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: AppSpacing.iconHuge,
                    color: AppColors.error,
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Title
            Text(
              title,
              style: AppTypography.headlineMedium.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppSpacing.md),

            // Message
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),

            // Retry button
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel ?? 'Try Again'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(150, AppSpacing.buttonLg),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
