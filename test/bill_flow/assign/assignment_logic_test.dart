import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_logic.dart';
import 'package:split_bill_app/services/friend_scanner_service.dart';

BillDraft _draft({
  Map<int, List<String>> items = const {},
  Map<int, Map<String, int>> units = const {},
}) => draftFromReceipt(
  receiptData: {
    'items': [
      {'name': 'Burger', 'price': 14.0, 'qty': 1},
      {'name': 'Fries', 'price': 6.0, 'qty': 1},
      {'name': 'Lemon mint', 'price': 3.0, 'qty': 3},
    ],
  },
  participantIds: const ['a', 'b', 'c'],
  currency: 'USD',
  itemAssignments: items,
  quantityAssignments: units,
);

void main() {
  group('assignmentProgress', () {
    test('counts only fully assigned items', () {
      final p = assignmentProgress(
        _draft(
          items: {
            0: ['a'],
          },
          units: {
            2: {'a': 1, 'b': 1},
          },
        ),
      );
      expect(p.assigned, 1);
      expect(p.total, 3);
      expect(p.left, 2);
      expect(p.isComplete, isFalse);
    });

    test('complete when every item is covered', () {
      final p = assignmentProgress(
        _draft(
          items: {
            0: ['a'],
            1: ['a', 'b'],
          },
          units: {
            2: {'a': 1, 'b': 1, 'c': 1},
          },
        ),
      );
      expect(p.isComplete, isTrue);
      expect(p.left, 0);
    });

    test('ignores unknown ids', () {
      final p = assignmentProgress(
        _draft(
          items: {
            0: ['ghost'],
          },
        ),
      );
      expect(p.assigned, 0);
    });
  });

  group('itemNoteFor', () {
    test('unassigned asks for a face', () {
      final note = itemNoteFor(_draft().assignmentOf(0));
      expect(note.kind, ItemNoteKind.unassigned);
      expect(note.key, 'bf_assign_note_tap_face');
      expect(note.needsAttention, isTrue);
    });

    test('one person: no note', () {
      final note = itemNoteFor(
        _draft(
          items: {
            0: ['a'],
          },
        ).assignmentOf(0),
      );
      expect(note, const ItemNote(ItemNoteKind.none));
      expect(note.key, isNull);
    });

    test('shared: split N ways', () {
      final note = itemNoteFor(
        _draft(
          items: {
            1: ['a', 'b'],
          },
        ).assignmentOf(1),
      );
      expect(note, const ItemNote(ItemNoteKind.splitWays, 2));
    });

    test('per unit, all equal: N each', () {
      final note = itemNoteFor(
        _draft(
          units: {
            2: {'a': 1, 'b': 1, 'c': 1},
          },
        ).assignmentOf(2),
      );
      expect(note, const ItemNote(ItemNoteKind.each, 1));
    });

    test('per unit, uneven and complete: no note', () {
      final note = itemNoteFor(
        _draft(
          units: {
            2: {'a': 2, 'b': 1},
          },
        ).assignmentOf(2),
      );
      expect(note.kind, ItemNoteKind.none);
    });

    test('per unit, partial: units left', () {
      final note = itemNoteFor(
        _draft(
          units: {
            2: {'a': 1},
          },
        ).assignmentOf(2),
      );
      expect(note, const ItemNote(ItemNoteKind.unitsLeft, 2));
      expect(note.needsAttention, isTrue);
    });

    test('per unit, over: too many', () {
      final note = itemNoteFor(
        _draft(
          units: {
            2: {'a': 3, 'b': 2},
          },
        ).assignmentOf(2),
      );
      expect(note, const ItemNote(ItemNoteKind.tooMany, 2));
    });
  });

  group('UnitCap', () {
    test('never increments past the quantity', () {
      var units = <String, int>{};
      units = UnitCap.increment(units, 'a', 2);
      units = UnitCap.increment(units, 'b', 2);
      units = UnitCap.increment(units, 'a', 2);
      expect(units, {'a': 1, 'b': 1});
      expect(UnitCap.remaining(units, 2), 0);
      expect(UnitCap.canAdd(units, 2), isFalse);
    });

    test('decrement drops the entry at zero', () {
      expect(UnitCap.decrement({'a': 2}, 'a'), {'a': 1});
      expect(UnitCap.decrement({'a': 1}, 'a'), isEmpty);
      expect(UnitCap.decrement({'a': 1}, 'b'), {'a': 1});
    });

    test('remaining is never negative', () {
      expect(UnitCap.remaining({'a': 5}, 3), 0);
    });

    test('clamp trims over-assigned legacy data from the end', () {
      expect(UnitCap.clamp({'a': 2, 'b': 2, 'c': 1}, 3), {'a': 2, 'b': 1});
      expect(UnitCap.clamp({'a': 0, 'b': -1, 'c': 1}, 3), {'c': 1});
      expect(UnitCap.clamp({'a': 1}, 3), {'a': 1});
    });
  });

  group('tapUnitFace', () {
    test('adds one unit, removes on second tap', () {
      final first = tapUnitFace(const {}, 'a', 3);
      expect(first.result, UnitTapResult.added);
      expect(first.units, {'a': 1});
      final second = tapUnitFace(first.units, 'a', 3);
      expect(second.result, UnitTapResult.removed);
      expect(second.units, isEmpty);
    });

    test('reports full instead of over-assigning', () {
      final tap = tapUnitFace(const {'a': 1, 'b': 1}, 'c', 2);
      expect(tap.result, UnitTapResult.full);
      expect(tap.units, {'a': 1, 'b': 1});
    });
  });

  test('toggleShared adds and removes', () {
    expect(toggleShared(['a'], 'b'), ['a', 'b']);
    expect(toggleShared(['a', 'b'], 'a'), ['b']);
  });

  test('removeParticipantAssignments clears the person and empty items', () {
    final r = removeParticipantAssignments(
      {
        0: ['a'],
        1: ['a', 'b'],
      },
      {
        2: {'a': 2},
        3: {'a': 1, 'b': 1},
      },
      'a',
    );
    expect(r.items, {
      1: ['b'],
    });
    expect(r.units, {
      3: {'b': 1},
    });
  });

  group('parseVoiceResult', () {
    test('legacy Map<String, List<String>>', () {
      final r = parseVoiceResult(
        <String, List<String>>{
          '0': ['a'],
          '1': ['a', 'b', 'ghost'],
          'x': ['a'],
        },
        knownIds: {'a', 'b'},
      )!;
      expect(r.items, {
        0: ['a'],
        1: ['a', 'b'],
      });
      expect(r.units, isEmpty);
    });

    test('wrapped assignments + splits; splits win', () {
      final r = parseVoiceResult(
        {
          'assignments': <String, List<String>>{
            '0': ['a'],
            '2': ['a', 'b'],
          },
          'splits': <String, Map<String, int>>{
            '2': {'a': 2, 'b': 1, 'c': 0},
          },
        },
        knownIds: {'a', 'b', 'c'},
        itemCount: 3,
      )!;
      expect(r.items, {
        0: ['a'],
      });
      expect(r.units, {
        2: {'a': 2, 'b': 1},
      });
    });

    test('drops out-of-range indexes', () {
      final r = parseVoiceResult({
        '5': ['a'],
      }, itemCount: 3)!;
      expect(r.isEmpty, isTrue);
    });

    test('null for non-maps', () {
      expect(parseVoiceResult(null), isNull);
      expect(parseVoiceResult('nope'), isNull);
    });
  });

  test('firstItemIssue picks the first item in receipt order', () {
    final issue = firstItemIssue(const [
      DiscountTooLargeIssue(10, 5),
      OverAssignedItemIssue(3, 4, 3),
      UnassignedItemIssue(1, 0, 1),
    ])!;
    expect(issue.index, 1);
    expect(issue.over, isFalse);
    expect(firstItemIssue(const [NoSharesIssue()]), isNull);
    final over = firstItemIssue(const [OverAssignedItemIssue(2, 5, 3)])!;
    expect(over.over, isTrue);
    expect(over.assigned, 5);
    expect(over.quantity, 3);
  });

  test('computeBill issues feed firstItemIssue', () {
    final issues = computeBill(
      _draft(
        items: {
          0: ['a'],
        },
      ),
    ).issues;
    expect(firstItemIssue(issues)!.index, 1);
  });

  test('guest participants get unique guest_ ids', () {
    final a = guestParticipant('  Mona ');
    final b = guestParticipant('Mona');
    expect(a['id'], startsWith('guest_'));
    expect(a['id'], isNot(b['id']));
    expect(a['name'], 'Mona');
    expect(a['isGuest'], isTrue);
  });

  test('participantFromProfile maps uid/displayName, guests get ids', () {
    final user = participantFromProfile({
      'uid': 'u1',
      'displayName': 'Sara',
      'isPro': true,
    });
    expect(user['id'], 'u1');
    expect(user['name'], 'Sara');
    expect(user['isPro'], isTrue);
    final guest = participantFromProfile(
      {'displayName': ''},
      isGuest: true,
      fallbackName: 'Guest',
    );
    expect(guest['id'], startsWith('guest_'));
    expect(guest['name'], 'Guest');
  });

  test('reconcileParticipants keeps hosts, drops deselected, appends', () {
    final r = reconcileParticipants(
      [
        {'id': 'h', 'isHost': true},
        {'id': 'a'},
        {'id': 'b'},
      ],
      [
        {'id': 'b'},
        {'id': 'c'},
      ],
    );
    expect(r.participants.map((x) => x['id']), ['h', 'b', 'c']);
    expect(r.removed, ['a']);
  });

  test('initialOf / firstNameOf', () {
    expect(initialOf('sara ali'), 'S');
    expect(initialOf(''), '?');
    expect(firstNameOf('Sara  Ali'), 'Sara');
  });

  group('parseFriendCode', () {
    test('raw uid', () {
      final c = parseFriendCode(' abcDEF123456 ');
      expect(c.kind, FriendCodeKind.friend);
      expect(c.uid, 'abcDEF123456');
    });

    test('link with uid', () {
      final c = parseFriendCode('https://split.example/add?uid=abcDEF123456');
      expect(c.uid, 'abcDEF123456');
    });

    test('own code', () {
      expect(
        parseFriendCode('abcDEF123456', selfUid: 'abcDEF123456').kind,
        FriendCodeKind.self,
      );
    });

    test('invalid', () {
      expect(parseFriendCode('').kind, FriendCodeKind.invalid);
      expect(parseFriendCode('hello world!').kind, FriendCodeKind.invalid);
      expect(
        parseFriendCode('https://example.com/').kind,
        FriendCodeKind.invalid,
      );
      expect(parseFriendCode('abc').kind, FriendCodeKind.invalid);
    });
  });
}
