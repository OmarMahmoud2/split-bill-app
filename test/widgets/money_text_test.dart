import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/money_text.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

String _shown(WidgetTester tester) {
  final text = tester.widget<Text>(find.byType(Text)).data!;
  return text.replaceAll(RegExp('[\u2066\u2069]'), '');
}

void main() {
  testWidgets('count-up ends on the exact final value', (tester) async {
    await tester.pumpWidget(
      _app(
        const MoneyText(
          minor: 6240,
          currency: 'USD',
          sign: MoneySign.always,
          animate: true,
          locale: 'en',
        ),
      ),
    );
    expect(_shown(tester), isNot(r'+$62.40'));
    await tester.pump(AppMotion.money ~/ 2);
    expect(_shown(tester), isNot(r'+$62.40'));
    await tester.pumpAndSettle();
    expect(_shown(tester), r'+$62.40');
  });

  testWidgets('animates from the previous value on change', (tester) async {
    Widget build(int minor) => _app(
      MoneyText(minor: minor, currency: 'JPY', animate: true, locale: 'en'),
    );
    await tester.pumpWidget(build(1000));
    await tester.pumpAndSettle();
    expect(_shown(tester), '¥1,000');
    await tester.pumpWidget(build(2000));
    await tester.pump(const Duration(milliseconds: 100));
    final mid = _shown(tester);
    expect(mid, isNot('¥2,000'));
    expect(mid, isNot('¥1,000'));
    await tester.pumpAndSettle();
    expect(_shown(tester), '¥2,000');
  });

  testWidgets('reduce motion shows the final value immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const MoneyText(
          minor: 1500,
          currency: 'KWD',
          animate: true,
          locale: 'en',
        ),
        reduceMotion: true,
      ),
    );
    expect(_shown(tester), '1.500\u00A0د.ك');
  });

  testWidgets('tone colors: owed mint, owe coral, zero ink', (tester) async {
    const p = AppPalette.light;
    Future<Color?> colorOf(Widget w) async {
      await tester.pumpWidget(_app(w));
      return tester.widget<Text>(find.byType(Text)).style?.color;
    }

    expect(await colorOf(MoneyText.money(const Money(100, 'USD'))), p.owed);
    expect(await colorOf(MoneyText.money(const Money(-100, 'USD'))), p.owe);
    expect(
      await colorOf(MoneyText.money(const Money(0, 'USD'))),
      p.textPrimary,
    );
    expect(
      await colorOf(
        const MoneyText(minor: 100, currency: 'USD', tone: MoneyTone.neutral),
      ),
      p.textPrimary,
    );
  });

  testWidgets('uses Plus Jakarta Sans with tabular figures', (tester) async {
    await tester.pumpWidget(
      _app(const MoneyText(minor: 1, currency: 'USD', size: MoneySize.hero)),
    );
    final style = tester.widget<Text>(find.byType(Text)).style!;
    expect(style.fontFamily, AppTypography.displayFamily);
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });
}
