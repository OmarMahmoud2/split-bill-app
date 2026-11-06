import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/widgets/locale_rebuilder.dart';

/// Stands in for a context-free `'key'.tr()` lookup.
String _label = 'Konto';

class _ConstLabel extends StatelessWidget {
  const _ConstLabel();
  @override
  Widget build(BuildContext context) => Text(_label);
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => taps++),
    child: Text('taps $taps'),
  );
}

Widget _app(Locale locale) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('de')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => LocaleRebuilder(child: child!),
  home: const Scaffold(body: Column(children: [_ConstLabel(), _Counter()])),
);

void main() {
  testStaleRace();
  testWidgets('a const label picks up the new language, state is kept', (
    tester,
  ) async {
    _label = 'Konto';
    await tester.pumpWidget(_app(const Locale('de')));
    await tester.tap(find.text('taps 0'));
    await tester.pump();
    expect(find.text('Konto'), findsOneWidget);

    _label = 'Account';
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('taps 1'), findsOneWidget);
  });

  testWidgets('no forced rebuild without a locale change', (tester) async {
    _label = 'Konto';
    await tester.pumpWidget(_app(const Locale('de')));
    _label = 'Account';
    await tester.pumpWidget(_app(const Locale('de')));
    await tester.pump();
    expect(find.text('Konto'), findsOneWidget);
  });
}

/// Mimics easy_localization: a global string table, a delegate that copies
/// the controller's table on load and never asks to reload.
Map<String, String> _controllerTable = {'title': 'Konto'};
Map<String, String> _instanceTable = {};

class _EasyLikeDelegate extends LocalizationsDelegate<Map<String, String>> {
  _EasyLikeDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<Map<String, String>> load(Locale locale) async {
    _instanceTable = Map.of(_controllerTable);
    return _instanceTable;
  }

  @override
  bool shouldReload(_EasyLikeDelegate old) => false;
}

class _TableLabel extends StatelessWidget {
  const _TableLabel();
  @override
  Widget build(BuildContext context) => Text(_instanceTable['title'] ?? '');
}

Widget _easyApp(Locale locale, LocalizationsDelegate<dynamic> delegate) =>
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: freshDelegates([
        delegate,
        ...GlobalMaterialLocalizations.delegates,
      ]),
      builder: (context, child) => LocaleRebuilder(child: child!),
      home: const Scaffold(body: _TableLabel()),
    );

void testStaleRace() {
  testWidgets('locale bound mid-load still ends on the new strings', (
    tester,
  ) async {
    _controllerTable = {'title': 'Konto'};
    await tester.pumpWidget(_easyApp(const Locale('de'), _EasyLikeDelegate()));
    await tester.pumpAndSettle();
    expect(find.text('Konto'), findsOneWidget);

    // setLocale(en) started: the app rebuilds with en before the file loads.
    final sameDelegate = _EasyLikeDelegate();
    await tester.pumpWidget(_easyApp(const Locale('en'), sameDelegate));
    await tester.pumpAndSettle();
    expect(find.text('Konto'), findsOneWidget); // stale, as on the device

    // The file arrives; EasyLocalization rebuilds with a new delegate.
    _controllerTable = {'title': 'Account'};
    await tester.pumpWidget(_easyApp(const Locale('en'), _EasyLikeDelegate()));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);
  });
}
