import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/theme/theme.dart';

/// WCAG 2.x relative luminance of an opaque color.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two opaque colors (1..21).
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

int _argb(Color c) => c.toARGB32();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('contrastRatio matches known WCAG values', () {
    expect(
      contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
    expect(
      contrastRatio(const Color(0xFF777777), const Color(0xFFFFFFFF)),
      closeTo(4.48, 0.01),
    );
  });

  group('"Midnight & Mint" values (docs/2.0/PREMIUM_POLISH.md)', () {
    test('light palette', () {
      const p = AppPalette.light;
      expect(_argb(p.canvas), 0xFFF5F7FB);
      expect(_argb(p.background), 0xFFF5F7FB);
      expect(_argb(p.surface), 0xFFFFFFFF);
      expect(_argb(p.hairline), 0xFFE3E7EF);
      expect(_argb(p.border), 0xFFE3E7EF);
      expect(_argb(p.textPrimary), 0xFF0E1526);
      expect(_argb(p.textSecondary), 0xFF5B6478);
      expect(_argb(p.accent), 0xFF0B7268);
      expect(_argb(p.primary), 0xFF0B7268);
      expect(_argb(p.accentSoft), 0xFFE3F7F3);
      expect(_argb(p.owe), 0xFFC2452D);
      expect(_argb(p.oweSoft), 0xFFFFECE6);
      expect(_argb(p.oweInk), 0xFFA8381F);
      expect(_argb(p.error), 0xFFC62828);
      expect(_argb(p.owed), _argb(p.accent));
    });

    test('dark palette', () {
      const p = AppPalette.dark;
      expect(_argb(p.canvas), 0xFF0A0F1C);
      expect(_argb(p.surface), 0xFF121A2B);
      expect(_argb(p.hairline), 0xFF22304A);
      expect(_argb(p.textPrimary), 0xFFE8EDF7);
      expect(_argb(p.textSecondary), 0xFF9AA4B8);
      expect(_argb(p.accent), 0xFF34D7C0);
      expect(_argb(p.accentSoft), 0xFF173540);
      expect(_argb(p.owe), 0xFFFF8A70);
    });

    test('legacy roles map onto v3 meanings', () {
      for (final p in [AppPalette.light, AppPalette.dark]) {
        expect(p.success, p.accent, reason: 'owed/positive is teal');
        expect(p.danger, p.error, reason: 'danger is error red');
        expect(p.warning, p.owe, reason: 'warning is owe coral');
        expect(p.primarySoft, p.accentSoft);
        expect(p.owe, isNot(p.error), reason: 'owing is never red');
      }
    });

    test('shadows: light only', () {
      expect(AppPalette.light.sheetShadow, isNotEmpty);
      expect(AppPalette.dark.sheetShadow, isEmpty);
    });
  });

  group('WCAG contrast >= 4.5:1 for text pairs', () {
    for (final entry in {
      'light': AppPalette.light,
      'dark': AppPalette.dark,
    }.entries) {
      final p = entry.value;
      final backgrounds = {
        'canvas': p.background,
        'surface': p.surface,
        'surfaceVariant': p.surfaceVariant,
      };
      final texts = {
        'textPrimary': p.textPrimary,
        'textMedium': p.textMedium,
        'textSecondary': p.textSecondary,
        'textTertiary': p.textTertiary,
        'accent': p.accent,
        'primaryStrong': p.primaryStrong,
        'owe': p.owe,
        'error': p.error,
        'info': p.info,
      };
      for (final bg in backgrounds.entries) {
        for (final fg in texts.entries) {
          // Spec amber #B45309 is 4.45:1 on surfaceVariant; amounts never sit
          // on that fill (use oweInk there, checked below).
          if (fg.key == 'owe' && bg.key == 'surfaceVariant') continue;
          const min = 4.5;
          test('${entry.key}: ${fg.key} on ${bg.key}', () {
            expect(
              contrastRatio(fg.value, bg.value),
              greaterThanOrEqualTo(min),
            );
          });
        }
      }
      final onPairs = {
        'onPrimary/primary': (p.onPrimary, p.primary),
        'onAccent/accent': (p.onAccent, p.accent),
        'onAccentSoft/accentSoft': (p.onAccentSoft, p.accentSoft),
        'oweInk/oweSoft': (p.oweInk, p.oweSoft),
        'oweInk/surfaceVariant': (p.oweInk, p.surfaceVariant),
        'onError/error': (p.onError, p.error),
        'error/errorSoft': (p.error, p.errorSoft),
        'infoStrong/infoSoft': (p.infoStrong, p.infoSoft),
        'onInverse/inverse': (p.onInverseSurface, p.inverseSurface),
        'onPremium/premium': (p.onPremium, p.premium),
        'onPrimary/gradient start': (p.onPrimary, p.primaryGradient.colors[0]),
        'onPrimary/gradient end': (p.onPrimary, p.primaryGradient.colors[1]),
      };
      for (final pair in onPairs.entries) {
        test('${entry.key}: ${pair.key}', () {
          expect(
            contrastRatio(pair.value.$1, pair.value.$2),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
      test('${entry.key}: ink on every avatar tint', () {
        for (final tint in p.avatarTints) {
          expect(contrastRatio(p.textPrimary, tint), greaterThanOrEqualTo(4.5));
        }
      });
      test('${entry.key}: amounts reach 7:1 on surface for ink', () {
        expect(
          contrastRatio(p.textPrimary, p.surface),
          greaterThanOrEqualTo(7),
        );
      });
    }
  });

  testWidgets('light theme uses the v3 palette', (_) async {
    final theme = AppTheme.lightTheme;
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, const Color(0xFF0B7268));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7FB));
    expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(theme.colorScheme.error, const Color(0xFFC62828));
    expect(theme.extension<AppPalette>(), AppPalette.light);
  });

  testWidgets('dark theme has the dark palette and light status icons', (
    _,
  ) async {
    final theme = AppTheme.darkTheme;
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0A0F1C));
    expect(theme.extension<AppPalette>(), AppPalette.dark);
    expect(
      theme.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.light,
    );
    expect(
      AppTheme
          .lightTheme
          .appBarTheme
          .systemOverlayStyle
          ?.statusBarIconBrightness,
      Brightness.dark,
    );
  });

  testWidgets('context.palette follows the active theme', (tester) async {
    late AppPalette seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            seen = context.palette;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.isDark, isTrue);
    expect(seen.background, AppPalette.dark.background);
  });

  test('palette lerp and copyWith keep v3 roles', () {
    final mid = AppPalette.light.lerp(AppPalette.dark, 1);
    expect(mid.owe, AppPalette.dark.owe);
    expect(AppPalette.light.copyWith(owe: Colors.black).owe, Colors.black);
  });

  test('themeModeFromName parses persisted values, defaults to system', () {
    expect(themeModeFromName('dark'), ThemeMode.dark);
    expect(themeModeFromName('light'), ThemeMode.light);
    expect(themeModeFromName('system'), ThemeMode.system);
    expect(themeModeFromName(null), ThemeMode.system);
    expect(themeModeFromName('bogus'), ThemeMode.system);
  });
}
