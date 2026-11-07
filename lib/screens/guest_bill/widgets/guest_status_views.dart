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
/// Sits in the page scroll (centred when there is room).
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
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
                if (footer != null) ...[const SizedBox(height: 32), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First paint while the bill loads: the page's shape in skeletons, matching
/// the real layout for the width (two columns on desktop for a personal
/// link, a centred column for the name picker). The top bar is the shell's.
class GuestLoadingSkeleton extends StatelessWidget {
  const GuestLoadingSkeleton({
    super.key,
    this.personal = false,
    this.twoColumn = false,
  });

  /// Personal link: receipt-shaped (no name picker).
  final bool personal;

  /// Desktop personal link: share card left, pay panel right.
  final bool twoColumn;

  static const _host = Row(
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
  );

  static Widget _card(int rows) => GuestCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Skeleton.line(width: 140, height: 12),
        const SizedBox(height: 10),
        const Skeleton.line(width: 190, height: 34),
        const SizedBox(height: 22),
        for (var i = 0; i < rows; i++) ...[
          const Row(
            children: [
              Expanded(child: Skeleton.line(width: 160)),
              SizedBox(width: 24),
              Skeleton.line(width: 56),
            ],
          ),
          if (i < rows - 1) const SizedBox(height: 14),
        ],
      ],
    ),
  );

  static const _tiles = Row(
    children: [
      Expanded(child: _Block(height: 64, radius: 16)),
      SizedBox(width: 8),
      Expanded(child: _Block(height: 64, radius: 16)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (!personal) {
      body = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _host,
          SizedBox(height: 24),
          Skeleton.line(width: 120, height: 14),
          SizedBox(height: 10),
          Row(
            children: [
              _ChipSkeleton(),
              SizedBox(width: 10),
              _ChipSkeleton(),
              SizedBox(width: 10),
              _ChipSkeleton(),
            ],
          ),
        ],
      );
    } else if (twoColumn) {
      body = LayoutBuilder(
        builder: (context, c) {
          final panel = (c.maxWidth - 32) * 0.4;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_host, const SizedBox(height: 16), _card(6)],
                ),
              ),
              const SizedBox(width: 32),
              SizedBox(
                width: panel,
                child: GuestCard(
                  padding: const EdgeInsets.all(20),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton.line(width: 100, height: 12),
                      SizedBox(height: 10),
                      Skeleton.line(width: 180, height: 40),
                      SizedBox(height: 20),
                      _tiles,
                      SizedBox(height: 8),
                      _tiles,
                      SizedBox(height: 16),
                      _Block(height: 56, radius: 16),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _host,
          const SizedBox(height: 16),
          _card(4),
          const SizedBox(height: 20),
          const Skeleton.line(width: 120, height: 14),
          const SizedBox(height: 10),
          _tiles,
        ],
      );
    }
    return SkeletonShimmer(
      child: Semantics(
        label: 'feedback_loading'.tr(),
        container: true,
        child: body,
      ),
    );
  }
}

/// The skeleton of the sticky "I've paid" bar (phone and tablet).
class GuestPayBarSkeleton extends StatelessWidget {
  const GuestPayBarSkeleton({super.key});

  @override
  Widget build(BuildContext context) =>
      const SkeletonShimmer(child: _Block(height: 56, radius: 16));
}

class _Block extends StatelessWidget {
  const _Block({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Skeleton(
    width: double.infinity,
    height: height,
    borderRadius: BorderRadius.all(Radius.circular(radius)),
  );
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
