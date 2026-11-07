import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/services/my_photo.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('pal variant is deterministic per seed and spreads across seeds', () {
    expect(PalAvatar.pairIndex('omar'), PalAvatar.pairIndex('omar'));
    expect(PalAvatar.hairVariant('omar'), PalAvatar.hairVariant('omar'));
    // FNV-1a 32-bit of "a" is 0xE40C292C (known test vector).
    expect(PalAvatar.hashSeed('a'), 0xE40C292C);
    final pairs = {for (var i = 0; i < 60; i++) PalAvatar.pairIndex('user$i')};
    final hairs = {for (var i = 0; i < 60; i++) PalAvatar.hairVariant('user$i')};
    expect(pairs.length, PalAvatar.pairs.length);
    expect(hairs.length, 3);
  });

  testWidgets('draws the pal without a photo and labels it with the name', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const PalAvatar(seed: 'omar', name: 'Omar', size: 48)),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel('Omar'), findsOneWidget);
    expect(tester.getSize(find.byType(PalAvatar)), const Size(48, 48));
  });

  testWidgets('shows the photo instead of the pal when photoUrl is set', (
    tester,
  ) async {
    // 1x1 transparent PNG as a data URL.
    const png =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    await tester.pumpWidget(
      _wrap(const PalAvatar(seed: 'omar', name: 'Omar', photoUrl: png)),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('ring adds padding around the avatar', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PalAvatar(seed: 's', size: 40, ringColor: Color(0xFF0E7C72)),
      ),
    );
    expect(
      tester.getSize(find.byType(PalAvatar)),
      const Size(45, 45),
    );
  });

  test('colour and hair vary independently: many distinct looks', () {
    final looks = {
      for (var i = 0; i < 60; i++)
        (PalAvatar.pairIndex('user$i'), PalAvatar.hairVariant('user$i')),
    };
    expect(looks.length, greaterThan(12));
  });

  testWidgets('the signed-in user ignores a photo stored on a bill', (
    tester,
  ) async {
    LedgerMe.debugOverride = const LedgerMe(uid: 'me', name: 'Omar');
    MyPhoto.notifier.value = null;
    addTearDown(() => LedgerMe.debugOverride = null);
    await tester.pumpWidget(
      _wrap(
        const PalAvatar(
          seed: 'me',
          name: 'Omar',
          photoUrl: 'https://lh3.googleusercontent.com/a/default-n',
        ),
      ),
    );
    // No chosen photo: the pal is drawn, the bill's Google photo is not.
    expect(find.byType(Image), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
