import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/screens/split_bill/widgets/add_people_screen.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assign_widgets.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_sheets.dart';
import 'package:split_bill_app/theme/theme.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.lightTheme,
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

final _people = <Map<String, dynamic>>[
  {'id': 'a', 'name': 'Ali'},
  {'id': 's', 'name': 'Sara Khaled'},
  {'id': 'm', 'name': 'Mona'},
];

ItemAssignmentState _state(
  int quantity, {
  List<String> people = const [],
  Map<String, int> units = const {},
}) {
  final draft = BillDraft(
    currency: 'USD',
    items: [DraftItem(name: 'x', unitPriceMinor: 100, quantity: quantity)],
    participantIds: const ['a', 's', 'm'],
    itemAssignments: people.isEmpty ? const {} : {0: people},
    quantityAssignments: units.isEmpty ? const {} : {0: units},
  );
  return draft.assignmentOf(0);
}

Finder _plus(String id) => find.byKey(ValueKey('bf_assign_units_plus_$id'));
Finder _minus(String id) => find.byKey(ValueKey('bf_assign_units_minus_$id'));
String _count(WidgetTester t, String id) =>
    t.widget<Text>(find.byKey(ValueKey('bf_assign_units_count_$id'))).data!;

void main() {
  setUp(() => AppMotion.debugReduceMotionOverride = true);
  tearDown(() => AppMotion.debugReduceMotionOverride = null);

  group('ComplexAssignmentSheet', () {
    testWidgets('cannot assign more units than the quantity', (tester) async {
      Map<String, int>? confirmed;
      await tester.pumpWidget(
        _app(
          ComplexAssignmentSheet(
            participants: _people,
            initialMap: const {},
            maxQty: 2,
            onConfirm: (m) => confirmed = m,
          ),
        ),
      );

      await tester.tap(_plus('a'));
      await tester.pump();
      await tester.tap(_plus('s'));
      await tester.pump();
      expect(_count(tester, 'a'), '1');
      expect(_count(tester, 's'), '1');

      // Every unit is taken: all "+" buttons are disabled.
      for (final id in ['a', 's', 'm']) {
        final button = tester.widget<IconButton>(_plus(id));
        expect(button.onPressed, isNull, reason: 'plus for $id');
      }
      await tester.tap(_plus('m'), warnIfMissed: false);
      await tester.pump();
      expect(_count(tester, 'm'), '0');

      // Freeing one unit re-enables "+".
      await tester.tap(_minus('a'));
      await tester.pump();
      expect(tester.widget<IconButton>(_plus('m')).onPressed, isNotNull);
      await tester.tap(_plus('m'));
      await tester.pump();

      await tester.tap(find.text('confirm_quantities'));
      await tester.pump();
      expect(confirmed, {'s': 1, 'm': 1});
    });

    testWidgets('shows remaining units', (tester) async {
      await tester.pumpWidget(
        _app(
          ComplexAssignmentSheet(
            participants: _people,
            initialMap: const {'a': 1},
            maxQty: 3,
            onConfirm: (_) {},
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('bf_assign_units_remaining')),
        findsOneWidget,
      );
      expect(find.text('bf_assign_units_remaining'), findsOneWidget);
    });

    testWidgets('trims an over-assigned initial map', (tester) async {
      Map<String, int>? confirmed;
      await tester.pumpWidget(
        _app(
          ComplexAssignmentSheet(
            participants: _people,
            initialMap: const {'a': 2, 's': 2},
            maxQty: 3,
            onConfirm: (m) => confirmed = m,
          ),
        ),
      );
      expect(_count(tester, 'a'), '2');
      expect(_count(tester, 's'), '1');
      expect(tester.widget<IconButton>(_plus('m')).onPressed, isNull);
      await tester.tap(find.text('confirm_quantities'));
      expect(confirmed, {'a': 2, 's': 1});
    });
  });

  testWidgets('SimpleAssignmentSheet toggles people and "for all"', (
    tester,
  ) async {
    final results = <List<String>>[];
    await tester.pumpWidget(
      _app(
        SimpleAssignmentSheet(
          participants: _people,
          currentSelection: const ['a'],
          onConfirm: results.add,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('bf_assign_simple_m')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bf_assign_simple_a')));
    await tester.pump();
    await tester.tap(find.text('done'));
    await tester.tap(find.text('for_all'));
    expect(results, [
      ['m'],
      ['a', 's', 'm'],
    ]);
  });

  group('AssignItemRow', () {
    Widget row(
      ItemAssignmentState state, {
      int quantity = 1,
      bool active = false,
      ValueChanged<String>? onFaceTap,
    }) => Material(
      child: AssignItemRow(
        item: DraftItem(name: 'Fries', unitPriceMinor: 300, quantity: quantity),
        state: state,
        participants: _people,
        currency: 'USD',
        active: active,
        onFaceTap: onFaceTap,
      ),
    );

    testWidgets('shows a chip per assignee and the split note', (tester) async {
      await tester.pumpWidget(_app(row(_state(1, people: ['a', 's']))));
      await tester.pumpAndSettle();
      expect(find.byType(AssigneeChip), findsNWidgets(2));
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Sara'), findsOneWidget);
      expect(find.text('bf_assign_note_split_ways'), findsOneWidget);
      expect(find.byType(AvatarHop), findsNWidgets(2));
      expect(find.textContaining('3.00'), findsOneWidget);
    });

    testWidgets('unassigned row asks for a face and uses the owe tint', (
      tester,
    ) async {
      await tester.pumpWidget(_app(row(_state(1))));
      await tester.pumpAndSettle();
      expect(find.byType(AssigneeChip), findsNothing);
      expect(find.text('bf_assign_note_tap_face'), findsOneWidget);
      final box = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(AssignItemRow),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        AppPalette.light.oweSoft,
      );
    });

    testWidgets('per-unit chips show units and the "each" note', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(row(_state(3, units: {'a': 1, 's': 1, 'm': 1}), quantity: 3)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AssigneeChip), findsNWidgets(3));
      expect(find.text('bf_assign_note_each'), findsOneWidget);
      expect(find.text('bf_assign_item_qty'), findsOneWidget);
    });

    testWidgets('active row shows faces and reports taps', (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(
        _app(row(_state(1, people: ['a']), active: true, onFaceTap: taps.add)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AssignFaceToggle), findsNWidgets(3));
      await tester.tap(find.byKey(const ValueKey('bf_assign_face_m')));
      expect(taps, ['m']);
      final ali = tester.widget<AssignFaceToggle>(
        find.byKey(const ValueKey('bf_assign_face_a')),
      );
      expect(ali.selected, isTrue);
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpWidget(_app(row(_state(1)), theme: AppTheme.darkTheme));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('PersonTotalsStrip shows each total', (tester) async {
    await tester.pumpWidget(
      _app(
        PersonTotalsStrip(
          participants: _people,
          totals: const {'a': 1250, 's': 700, 'm': 0},
          currency: 'USD',
          highlightedIds: const {'a'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PersonTotalCard), findsNWidgets(3));
    expect(find.textContaining('12.50'), findsOneWidget);
    expect(find.textContaining('7.00'), findsOneWidget);
  });

  testWidgets('AddPeopleScreen: host stays, guests are added and removed', (
    tester,
  ) async {
    List<Map<String, dynamic>>? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await AddPeopleScreen.open(
                    context,
                    participants: [
                      {'id': 'h', 'name': 'Omar', 'isHost': true},
                      {'id': 'a', 'name': 'Ali'},
                    ],
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bf_assign_selected_h')), findsOneWidget);
    expect(find.byKey(const ValueKey('bf_assign_selected_a')), findsOneWidget);

    // Remove Ali via the chip.
    await tester.tap(find.byKey(const ValueKey('bf_assign_selected_a')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bf_assign_selected_a')), findsNothing);
    // The host chip cannot be removed.
    await tester.tap(find.byKey(const ValueKey('bf_assign_selected_h')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bf_assign_selected_h')), findsOneWidget);

    // Type a name and add it as a guest.
    await tester.enterText(
      find.byKey(const ValueKey('bf_assign_people_search')),
      'Mona',
    );
    await tester.pump();
    await tester.tap(find.text('bf_assign_add_query_as_guest'));
    await tester.pump();
    // Let the confirmation toast time out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bf_assign_people_continue')));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.map((x) => x['name']), ['Omar', 'Mona']);
    expect(result!.last['id'], startsWith('guest_'));
    expect(result!.last['isGuest'], isTrue);
  });
}
