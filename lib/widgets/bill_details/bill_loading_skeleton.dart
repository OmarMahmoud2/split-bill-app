import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

/// Skeleton of a bill view while it loads.
class BillLoadingSkeleton extends StatelessWidget {
  const BillLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: Semantics(
        label: 'bf_bill_loading'.tr(),
        child: SkeletonShimmer(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 12),
              const Row(
                children: [
                  Skeleton.circle(size: 44),
                  Spacer(),
                  Skeleton.circle(size: 44),
                ],
              ),
              const SizedBox(height: 20),
              const FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 0.6,
                child: Skeleton.line(),
              ),
              const SizedBox(height: 10),
              const FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 0.45,
                child: Skeleton.line(height: 40),
              ),
              const SizedBox(height: 16),
              const Skeleton.line(height: 8),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: p.hairline),
                ),
                child: const Column(
                  children: [
                    SkeletonListTile(),
                    SkeletonListTile(),
                    SkeletonListTile(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SkeletonCard(),
            ],
          ),
        ),
      ),
    );
  }
}
