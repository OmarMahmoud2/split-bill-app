import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/screens/scan_receipt/review_banner_content.dart';
import 'package:split_bill_app/theme/theme.dart';

/// The amber "check this" (or calm "all good") note above the review list.
class ReviewBanner extends StatelessWidget {
  const ReviewBanner({super.key, required this.content});

  final ReviewBannerContent content;

  static String _translate(String key, Map<String, String> args) =>
      key.tr(namedArgs: args);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final warning = content.tone == ReviewBannerTone.warning;
    final background = warning ? p.oweSoft : p.accentSoft;
    final foreground = warning ? p.oweInk : p.onAccentSoft;
    final text = content.text(_translate);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const ValueKey('scan-review-banner'),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadii.rowRadius,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 1),
              child: Icon(
                warning ? AppIcons.warning : AppIcons.success,
                size: 16,
                color: foreground,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
