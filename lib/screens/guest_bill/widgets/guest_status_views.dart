import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

import 'guest_chrome.dart';

/// Sent / paid: a small badge beside the title and message.
class GuestStatusNote extends StatelessWidget {
  const GuestStatusNote({
    super.key,
    required this.confirmed,
    required this.title,
    required this.message,
  });

  final bool confirmed;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: confirmed ? p.successSoft : p.skySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              confirmed ? AppIcons.check : AppIcons.hourglass,
              size: 20,
              color: confirmed ? p.successStrong : p.sky,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 16,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    color: p.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Settled / expired / not found: a quiet message with one way forward.
class GuestMessageView extends StatelessWidget {
  const GuestMessageView({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.footer,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 26,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: 15,
                          height: 1.5,
                          color: p.textSecondary,
                        ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(height: 22),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(64, 54),
                            side: BorderSide(color: p.borderStrong),
                          ),
                          onPressed: onAction,
                          child: Text(actionLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}

/// First paint while the bill loads: the page's shape in skeletons.
class GuestLoadingSkeleton extends StatelessWidget {
  const GuestLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Semantics(
        label: 'feedback_loading'.tr(),
        container: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Skeleton.circle(size: 48),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton.line(width: 220),
                        SizedBox(height: 8),
                        Skeleton.line(width: 150, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Skeleton.line(width: 120, height: 14),
              const SizedBox(height: 10),
              const Row(
                children: [
                  _ChipSkeleton(),
                  SizedBox(width: 10),
                  _ChipSkeleton(),
                  SizedBox(width: 10),
                  _ChipSkeleton(),
                ],
              ),
              const SizedBox(height: 18),
              const GuestCard(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton.line(width: 140, height: 12),
                    SizedBox(height: 10),
                    Skeleton.line(width: 190, height: 34),
                    SizedBox(height: 22),
                    Skeleton.line(),
                    SizedBox(height: 10),
                    Skeleton.line(),
                    SizedBox(height: 10),
                    Skeleton.line(width: 200),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipSkeleton extends StatelessWidget {
  const _ChipSkeleton();

  @override
  Widget build(BuildContext context) => const Skeleton(
    width: 96,
    height: 48,
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );
}
