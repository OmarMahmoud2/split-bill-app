import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/utils/app_theme.dart';

/// Overridable so the suite can run against a translations checkout.
const _dir = String.fromEnvironment(
  'TRANSLATIONS_DIR',
  defaultValue: 'assets/translations',
);

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$_dir/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

/// Pumps [home] inside EasyLocalization + the app themes.
Future<void> pumpAccount(
  WidgetTester tester,
  Widget home, {
  ThemeMode themeMode = ThemeMode.light,
  String locale = 'en',
  Size size = const Size(402, 874),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(locale),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _Translations(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
