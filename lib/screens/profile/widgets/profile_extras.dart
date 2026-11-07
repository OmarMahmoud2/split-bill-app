import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/brand/brand_intro.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';

/// Compact "What's an IOU?" row; the full explainer opens in a small sheet.
class IouCard extends StatelessWidget {
  const IouCard({super.key, required this.onAdd});

  final VoidCallback onAdd;

  void _explain(BuildContext context) {
    showLedgerSheet<void>(
      context,
      title: 'you_iou_title'.tr(),
      builder: (sheetContext) {
        final p = sheetContext.palette;
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'you_iou_body'.tr(),
                style: AppTypography.bodyLarge.copyWith(
                  color: p.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('iou-sheet-add'),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onAdd();
                },
                child: Text('yx_iou_add'.tr()),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
      child: Pressable(
        key: const ValueKey('profile-iou'),
        haptic: true,
        onTap: () => _explain(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: p.hairline),
            boxShadow: p.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(AppIcons.iou, size: 20, color: p.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'you_iou_title'.tr(),
                      style: AppTypography.titleSmall.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'yx_iou_line'.tr(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                key: const ValueKey('profile-add-iou'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(64, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () {
                  AppHaptics.light();
                  onAdd();
                },
                child: Text('yx_iou_add'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sliding gradient used for the Pro card shimmer.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);
  final double t;
  @override
  Matrix4? transform(Rect bounds, {ui.TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 3 - 1.5), 0, 0);
}

/// Attention-grabbing Pro card for free users; a small plan card for Pro.
class ProCard extends StatefulWidget {
  const ProCard({
    super.key,
    required this.isPro,
    required this.planLabel,
    required this.onTap,
  });

  final bool isPro;
  final String? planLabel;
  final VoidCallback onTap;

  @override
  State<ProCard> createState() => _ProCardState();
}

class _ProCardState extends State<ProCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context) || widget.isPro) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (widget.isPro) return _pro(p);

    final dark = p.isDark;
    final reduce = AppMotion.reduceMotion(context);
    final ink = dark ? p.onHero : Colors.white;
    const benefits = ['yx_pro_b1', 'yx_pro_b2', 'yx_pro_b3'];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
      child: Pressable(
        key: const ValueKey('profile-pro-card'),
        haptic: true,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              borderRadius: AppRadii.cardRadius,
              gradient: dark
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0E1B33), Color(0xFF16294A)],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [p.accent, p.sky],
                    ),
              border: dark ? Border.all(color: p.heroLine) : null,
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(
                    alpha: 0.18 + (reduce ? 0 : 0.14 * _c.value),
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: AppRadii.cardRadius,
              child: Stack(
                children: [
                  if (dark)
                    PositionedDirectional(
                      top: -60,
                      end: -40,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              p.accent.withValues(alpha: 0.35),
                              p.accent.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!reduce)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.16),
                                Colors.white.withValues(alpha: 0),
                              ],
                              stops: const [0.35, 0.5, 0.65],
                              transform: _SlideGradient(_c.value),
                            ),
                          ),
                        ),
                      ),
                    ),
                  child!,
                ],
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            AppIcons.sparkle,
                            size: 26,
                            color: (dark ? p.accent : Colors.white).withValues(
                              alpha: 0.35,
                            ),
                          ),
                          Icon(
                            AppIcons.crown,
                            size: 22,
                            color: dark ? p.gold : Colors.white,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'yx_pro_title'.tr(),
                        style: AppTypography.headlineMedium.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(AppIcons.sparkle, color: dark ? p.gold : ink),
                  ],
                ),
                const SizedBox(height: 14),
                for (final k in benefits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.check,
                          size: 16,
                          color: dark ? p.accent : ink,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            k.tr(),
                            style: AppTypography.bodyMedium.copyWith(
                              color: ink.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dark ? p.accent : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Text(
                    'yx_pro_cta'.tr(),
                    style: AppTypography.titleSmall.copyWith(
                      color: dark ? p.onMint : p.sky,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pro(AppPalette p) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
      child: Pressable(
        key: const ValueKey('profile-pro-active'),
        haptic: true,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: p.accent.withValues(alpha: 0.5)),
            boxShadow: p.softShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: p.hero,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(AppIcons.crown, size: 20, color: p.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'yx_pro_active'.tr(),
                      style: AppTypography.titleSmall.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      widget.planLabel ?? 'prof_plan_pro'.tr(),
                      style: AppTypography.bodySmall.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'yx_pro_manage'.tr(),
                style: AppTypography.labelLarge.copyWith(
                  color: p.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(AppIcons.chevronRight, size: 18, color: p.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Branded footer: mark, wordmark, tagline, version and legal links.
class EvensFooter extends StatelessWidget {
  const EvensFooter({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final links = <(String, String, String)>[
      ('footer-privacy', 'yx_link_privacy', AppLinks.privacyPolicyUrl),
      ('footer-terms', 'yx_link_terms', AppLinks.termsOfUseUrl),
      ('footer-support', 'yx_link_support', AppLinks.supportUrl),
      ('footer-website', 'yx_link_website', AppLinks.websiteUrl),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const EvensMark(size: 44),
          const SizedBox(height: 8),
          Text(
            'Evens',
            style: AppTypography.headlineMedium.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'fr_tagline'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: 6),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              return Text(
                info == null
                    ? 'app_version_loading'.tr()
                    : 'app_version_build'.tr(
                        namedArgs: {
                          'version': info.version,
                          'build': info.buildNumber,
                        },
                      ),
                style: TextStyle(fontSize: 12, color: p.textDisabled),
              );
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final l in links)
                TextButton(
                  key: ValueKey(l.$1),
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  onPressed: () => onOpen(l.$3),
                  child: Text(l.$2.tr()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Red-tinted "Danger zone" card holding Delete account.
class DangerZoneCard extends StatelessWidget {
  const DangerZoneCard({super.key, required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: p.errorSoft.withValues(alpha: p.isDark ? 0.25 : 0.6),
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: p.error.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 0),
              child: Row(
                children: [
                  Icon(AppIcons.warning, size: 16, color: p.error),
                  const SizedBox(width: 6),
                  Text(
                    'yx_danger_title'.tr(),
                    style: AppTypography.labelLarge.copyWith(
                      color: p.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Pressable(
              key: const ValueKey('profile-delete-account'),
              haptic: true,
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'yx_danger_delete'.tr(),
                            style: AppTypography.titleSmall.copyWith(
                              color: p.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'yx_danger_sub'.tr(),
                            style: AppTypography.bodySmall.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(AppIcons.delete, color: p.error),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
