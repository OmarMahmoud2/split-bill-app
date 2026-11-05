import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('light theme keeps the pre-token brand values', (_) async {
    final theme = AppTheme.lightTheme;
    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, const Color(0xFF00ACC1));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F7FA));
    expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(theme.extension<AppPalette>(), AppPalette.light);
  });

  test('light palette matches the Material shades screens used', () {
    const p = AppPalette.light;
    int argb(Color c) => c.toARGB32();
    expect(argb(p.surfaceVariant), argb(Colors.grey[100]!));
    expect(argb(p.surfaceMuted), argb(Colors.grey[50]!));
    expect(argb(p.border), argb(Colors.grey[300]!));
    expect(argb(p.borderSubtle), argb(Colors.grey[200]!));
    expect(argb(p.textSecondary), argb(Colors.grey[600]!));
    expect(argb(p.textTertiary), argb(Colors.grey[500]!));
    expect(argb(p.textDisabled), argb(Colors.grey[400]!));
    expect(argb(p.success), argb(Colors.green));
    expect(argb(p.successStrong), argb(Colors.green[700]!));
    expect(argb(p.danger), argb(Colors.red));
    expect(argb(p.dangerStrong), argb(Colors.red[700]!));
    expect(argb(p.dangerAccent), argb(Colors.redAccent));
    expect(argb(p.warning), argb(Colors.orange));
    expect(argb(p.warningStrong), argb(Colors.orange[800]!));
    expect(argb(p.info), argb(Colors.blue));
    expect(argb(p.infoStrong), argb(Colors.blue[800]!));
    expect(argb(p.infoAccent), argb(Colors.blueAccent));
  });

  testWidgets('dark theme has the dark palette and light status icons', (
    _,
  ) async {
    final theme = AppTheme.darkTheme;
    expect(theme.brightness, Brightness.dark);
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

  test('themeModeFromName parses persisted values, defaults to system', () {
    expect(themeModeFromName('dark'), ThemeMode.dark);
    expect(themeModeFromName('light'), ThemeMode.light);
    expect(themeModeFromName('system'), ThemeMode.system);
    expect(themeModeFromName(null), ThemeMode.system);
    expect(themeModeFromName('bogus'), ThemeMode.system);
  });
}
