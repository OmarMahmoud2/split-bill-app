import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/config/supported_preferences.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';

import '../guest_locale.dart';

/// Brand wordmark used in the guest headers.
class GuestBrand extends StatelessWidget {
  const GuestBrand({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      header: true,
      child: Text.rich(
        TextSpan(
          text: 'evens',
          children: [TextSpan(text: '.', style: TextStyle(color: p.primary))],
        ),
        style: AppTypography.headlineMedium.copyWith(
          fontSize: large ? 22 : 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: p.textPrimary,
        ),
      ),
    );
  }
}

/// A 44px-tall outlined pill (language switcher, store links).
class GuestPill extends StatelessWidget {
  const GuestPill({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool filled;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14),
      ),
      textStyle: WidgetStatePropertyAll(
        AppTypography.labelLarge.copyWith(fontSize: 14),
      ),
      shape: const WidgetStatePropertyAll(AppRadii.pill),
      side: filled
          ? null
          : WidgetStatePropertyAll(BorderSide(color: p.borderStrong)),
      backgroundColor: WidgetStatePropertyAll(
        filled ? p.inverseSurface : p.surface,
      ),
      foregroundColor: WidgetStatePropertyAll(
        filled ? p.onInverseSurface : p.textPrimary,
      ),
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: semanticsLabel != null,
      child: OutlinedButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

/// Shows the current language; opens a list of all 22.
class GuestLanguageButton extends StatelessWidget {
  const GuestLanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final current = findLocaleOption(
      Localizations.localeOf(context).languageCode,
    );
    return GuestPill(
      label: current.nativeName,
      icon: AppIcons.language,
      semanticsLabel: '${'guest_language'.tr()}: ${current.nativeName}',
      onPressed: () => showGuestLanguagePicker(context),
    );
  }
}

Future<void> showGuestLanguagePicker(BuildContext context) async {
  final current = Localizations.localeOf(context).languageCode;
  final wide = MediaQuery.sizeOf(context).width >= 600;
  Widget list(BuildContext sheetContext) {
    final p = sheetContext.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 8),
          child: Text(
            'guest_language'.tr(),
            style: AppTypography.headlineMedium.copyWith(color: p.textPrimary),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final option in supportedLocaleOptions)
                ListTile(
                  minTileHeight: 48,
                  title: Text(
                    option.nativeName,
                    style: AppTypography.bodyLarge.copyWith(
                      color: p.textPrimary,
                      fontWeight: option.code == current
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  subtitle: option.nativeName == option.englishName
                      ? null
                      : Text(
                          option.englishName,
                          style: AppTypography.bodySmall.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                  trailing: option.code == current
                      ? Icon(AppIcons.check, color: p.primary)
                      : null,
                  selected: option.code == current,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    GuestLocale.choose(context, option.locale);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  if (wide) {
    await showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: list(c),
        ),
      ),
    );
  } else {
    await showLedgerSheet<void>(context, builder: list);
  }
}

Future<void> openStore(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await launchUrl(uri);
  }
}

/// The store this browser's device uses, or null on desktop.
String? get mobileStoreUrl => switch (defaultTargetPlatform) {
  TargetPlatform.iOS => AppLinks.appStoreUrl,
  TargetPlatform.android => AppLinks.playStoreUrl,
  _ => null,
};

/// App Store + Google Play buttons.
class GuestStoreButtons extends StatelessWidget {
  const GuestStoreButtons({super.key, this.onInk = false});

  /// Light buttons for the ink "get the app" card.
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    ButtonStyle style() => FilledButton.styleFrom(
      backgroundColor: onInk ? p.onHero : p.hero,
      foregroundColor: onInk ? p.hero : p.onHero,
      minimumSize: const Size(44, 46),
      textStyle: AppTypography.labelLarge.copyWith(fontSize: 15),
    );
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          style: style(),
          onPressed: () => openStore(AppLinks.appStoreUrl),
          icon: const Icon(AppIcons.apple, size: 20),
          label: Text('web_download_app_store'.tr()),
        ),
        FilledButton.icon(
          style: style(),
          onPressed: () => openStore(AppLinks.playStoreUrl),
          icon: const Icon(AppIcons.android, size: 20),
          label: Text('web_download_play_store'.tr()),
        ),
      ],
    );
  }
}

/// "Split your next bill in seconds" ink card.
class GuestGetAppCard extends StatelessWidget {
  const GuestGetAppCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final store = mobileStoreUrl;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.heroLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'guest_get_app_title'.tr(),
            style: AppTypography.titleMedium.copyWith(
              fontSize: 16,
              color: p.onHero,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'guest_get_app_body'.tr(),
            style: AppTypography.bodyMedium.copyWith(
              color: p.onHero.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 12),
          if (store != null)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: p.onHero,
                foregroundColor: p.hero,
                minimumSize: const Size(44, 46),
              ),
              onPressed: () => openStore(store),
              child: Text('guest_get_app'.tr()),
            )
          else
            const GuestStoreButtons(onInk: true),
        ],
      ),
    );
  }
}

/// Desktop header "Get the app" pill: one store on phones, a menu otherwise.
class GuestGetAppPill extends StatelessWidget {
  const GuestGetAppPill({super.key});

  @override
  Widget build(BuildContext context) {
    final store = mobileStoreUrl;
    if (store != null) {
      return GuestPill(
        label: 'guest_get_app'.tr(),
        onPressed: () => openStore(store),
      );
    }
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(AppIcons.apple),
          onPressed: () => openStore(AppLinks.appStoreUrl),
          child: Text('web_download_app_store'.tr()),
        ),
        MenuItemButton(
          leadingIcon: const Icon(AppIcons.android),
          onPressed: () => openStore(AppLinks.playStoreUrl),
          child: Text('web_download_play_store'.tr()),
        ),
      ],
      builder: (context, controller, _) => GuestPill(
        label: 'guest_get_app'.tr(),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// The person's pal (never initials), optionally with a ring.
class GuestAvatar extends StatelessWidget {
  const GuestAvatar({
    super.key,
    required this.id,
    required this.name,
    this.size = 40,
    this.ringColor,
  });

  final String id;
  final String name;
  final double size;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: PalAvatar(
      seed: id.isEmpty ? name.toLowerCase() : id,
      name: name,
      size: size,
      ringColor: ringColor,
    ),
  );
}

/// A hairline card (v3: 1px border, 20px radius, no shadow).
class GuestCard extends StatelessWidget {
  const GuestCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor ?? p.border),
        boxShadow: p.isDark
            ? null
            : [
                BoxShadow(
                  color: p.shadow.withValues(alpha: 0.06),
                  offset: const Offset(0, 10),
                  blurRadius: 24,
                ),
              ],
      ),
      child: child,
    );
  }
}

/// Dashed rounded border (upload drop zone).
class GuestDashedBorder extends StatelessWidget {
  const GuestDashedBorder({
    super.key,
    required this.child,
    this.radius = 20,
    this.color,
  });

  final Widget child;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(
        color: color ?? context.palette.borderStrong,
        radius: radius,
      ),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(0.75);
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
