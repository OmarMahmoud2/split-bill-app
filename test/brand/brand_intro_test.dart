import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/utils/app_theme.dart';
import 'package:split_bill_app/widgets/brand/brand_intro.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: child,
  ),
);

class _Probe extends StatefulWidget {
  const _Probe(this.onInit);
  final VoidCallback onInit;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const Text('probe');
}

void main() {
  setUp(() => BrandIntro.played = false);

  testWidgets('plays once over the app, then shows only the app', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const BrandIntro(child: Text('app'))));
    expect(find.text('app'), findsOneWidget);
    expect(find.byType(EvensMark), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Evens'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(EvensMark), findsNothing);
    expect(find.text('app'), findsOneWidget);
    expect(BrandIntro.played, isTrue);

    // A second intro in the same process does not replay.
    await tester.pumpWidget(_app(const BrandIntro(child: Text('again'))));
    expect(find.byType(EvensMark), findsNothing);
  });

  testWidgets('the child State survives the end of the intro', (tester) async {
    var inits = 0;
    await tester.pumpWidget(
      _app(BrandIntro(child: _Probe(() => inits++))),
    );
    final before = tester.state(find.byType(_Probe));
    await tester.pumpAndSettle();
    expect(find.byType(EvensMark), findsNothing);
    expect(tester.state(find.byType(_Probe)), same(before));
    expect(inits, 1);
  });

  testWidgets('is skipped under Reduce Motion', (tester) async {
    await tester.pumpWidget(
      _app(const BrandIntro(child: Text('app')), reduceMotion: true),
    );
    await tester.pump();
    expect(find.byType(EvensMark), findsNothing);
    expect(find.text('app'), findsOneWidget);
  });

  testWidgets('the mark paints in light and dark', (tester) async {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: const Center(child: EvensMark())),
      );
      expect(find.byType(EvensMark), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
