import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

class SuccessStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onAction;
  final String? actionLabel;

  const SuccessStateWidget({
    super.key,
    required this.message,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/success.json',
              width: 200,
              height: 200,
              repeat: false,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.check_circle_outline,
                size: 100,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              message,
              style: AppTypography.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (onAction != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'common_continue'.tr()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
