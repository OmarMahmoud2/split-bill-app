import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:upgrader/upgrader.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/theme/theme.dart';

class CustomUpgrader extends StatefulWidget {
  final Widget child;
  final Upgrader? upgrader;

  const CustomUpgrader({super.key, required this.child, this.upgrader});

  @override
  State<CustomUpgrader> createState() => _CustomUpgraderState();
}

class _CustomUpgraderState extends State<CustomUpgrader> {
  late Upgrader _upgrader;

  @override
  void initState() {
    super.initState();
    _upgrader =
        widget.upgrader ??
        Upgrader(
          debugDisplayAlways: false, // Set to true for testing
        );
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      await _upgrader.initialize();
      if (_upgrader.isUpdateAvailable()) {
        if (mounted) {
          _showCustomUpdateDialog();
        }
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
    }
  }

  void _showCustomUpdateDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'update_available'.tr(),
      transitionDuration: AppMotion.durationFor(
        context,
        const Duration(milliseconds: 500),
      ),
      pageBuilder: (context, anim1, anim2) => UpdateDialogContent(
        animation: anim1,
        version: _upgrader.currentAppStoreVersion,
        onUpdate: _openStore,
        onLater: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(AppLinks.storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// The update prompt itself: v3 tokens, translated, and a plain fade (no
/// bounce, no looping animation) under Reduce Motion.
class UpdateDialogContent extends StatelessWidget {
  const UpdateDialogContent({
    super.key,
    required this.animation,
    required this.onUpdate,
    required this.onLater,
    this.version,
  });

  final Animation<double> animation;
  final String? version;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduce = AppMotion.reduceMotion(context);
    final card = Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: p.shadow.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: SizedBox(
                height: 140,
                child: reduce
                    ? Icon(
                        AppIcons.rocket,
                        size: 100,
                        color: p.infoAccent,
                      )
                    : Lottie.asset(
                        'assets/animations/update_rocket.json',
                        errorBuilder: (c, e, s) => Icon(
                          AppIcons.rocket,
                          size: 100,
                          color: p.infoAccent,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                'update_available'.tr(),
                style: AppTypography.headlineLarge.copyWith(
                  color: p.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              version == null || version!.isEmpty
                  ? 'update_new_version_available'.tr()
                  : 'update_version_available'.tr(
                      namedArgs: {'version': version!},
                    ),
              style: AppTypography.titleSmall.copyWith(
                color: p.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'we_ve_added_new_features_and_fixed_some_bugs_to_improve_your_experience'
                  .tr(),
              style: AppTypography.bodyMedium.copyWith(
                color: p.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onUpdate,
                child: Text('update_now'.tr()),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onLater,
              child: Text(
                'later'.tr(),
                style: AppTypography.labelLarge.copyWith(
                  color: p.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ColoredBox(
            color: p.scrim.withValues(alpha: 0.5),
            child: const SizedBox.expand(),
          ),
        ),
        Center(
          child: reduce
              ? FadeTransition(opacity: animation, child: card)
              : ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.elasticOut,
                  ),
                  child: card,
                ),
        ),
      ],
    );
  }
}
