import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/domain/domain_errors.dart';
import 'package:split_bill_app/domain/split_methods.dart';

int _sum(Map<String, int> m) => m.values.fold(0, (a, b) => a + b);

void main() {
  group('allocateByWeights (largest remainder)', () {
    test('distributes exactly proportional amounts', () {
      expect(allocateByWeights(1000, {'a': 1, 'b': 3}), {'a': 250, 'b': 750});
    });

    test('gives remainder to the largest fractional parts', () {
      // 100 * 1/6 = 16.67, 100 * 2/6 = 33.33, 100 * 3/6 = 50
      final r = allocateByWeights(100, {'a': 1, 'b': 2, 'c': 3});
      expect(r, {'a': 17, 'b': 33, 'c': 50});
      expect(_sum(r), 100);
    });

    test('ties are broken by input order (stable)', () {
      expect(allocateByWeights(2, {'x': 1, 'y': 1, 'z': 1}),
          {'x': 1, 'y': 1, 'z': 0});
      expect(allocateByWeights(2, {'z': 1, 'y': 1, 'x': 1}),
          {'z': 1, 'y': 1, 'x': 0});
    });

    test('preserves input key order in the result', () {
      final r = allocateByWeights(10, {'c': 1, 'a': 1, 'b': 1});
      expect(r.keys.toList(), ['c', 'a', 'b']);
    });

    test('zero weight receives nothing', () {
      expect(allocateByWeights(101, {'a': 1, 'b': 0, 'c': 1}),
          {'a': 51, 'b': 0, 'c': 50});
    });

    test('zero total', () {
      expect(allocateByWeights(0, {'a': 1, 'b': 2}), {'a': 0, 'b': 0});
    });

    test('rejects negative total and weights, and all-zero weights', () {
      expect(() => allocateByWeights(-1, {'a': 1}),
          throwsA(isA<NegativeAmountError>()));
      expect(() => allocateByWeights(10, {'a': -1, 'b': 2}),
          throwsA(isA<NegativeAmountError>()));
      expect(() => allocateByWeights(10, {'a': 0, 'b': 0}),
          throwsA(isA<ZeroTotalWeightError>()));
      expect(() => allocateByWeights(10, {}),
          throwsA(isA<EmptyParticipantsError>()));
    });

    test('does not overflow on large totals and weights', () {
      final r = allocateByWeights(
          9000000000000000, {'a': 333333333, 'b': 666666667});
      expect(_sum(r), 9000000000000000);
    });
  });

  group('splitEqually', () {
    test('single person gets everything', () {
      expect(splitEqually(1234, ['solo']), {'solo': 1234});
    });

    test('even split', () {
      expect(splitEqually(900, ['a', 'b', 'c']), {'a': 300, 'b': 300, 'c': 300});
    });

    test('10.00 among 3 -> 3.34, 3.33, 3.33', () {
      expect(splitEqually(1000, ['a', 'b', 'c']),
          {'a': 334, 'b': 333, 'c': 333});
    });

    test('many participants always sum to total', () {
      final people = List.generate(37, (i) => 'p$i');
      for (final total in [0, 1, 36, 37, 38, 99999, 123456789]) {
        final r = splitEqually(total, people);
        expect(_sum(r), total);
        final values = r.values.toSet();
        expect(values.length, lessThanOrEqualTo(2));
        if (values.length == 2) {
          expect((values.first - values.last).abs(), 1);
        }
      }
    });

    test('zero amount', () {
      expect(splitEqually(0, ['a', 'b']), {'a': 0, 'b': 0});
    });

    test('validation', () {
      expect(() => splitEqually(100, []),
          throwsA(isA<EmptyParticipantsError>()));
      expect(() => splitEqually(100, ['a', 'a']),
          throwsA(isA<DuplicateParticipantError>()));
      expect(() => splitEqually(-100, ['a']),
          throwsA(isA<NegativeAmountError>()));
    });
  });

  group('splitByExactAmounts', () {
    test('returns the amounts when they match the total', () {
      expect(splitByExactAmounts(1000, {'a': 250, 'b': 750}),
          {'a': 250, 'b': 750});
    });

    test('allows zero for a participant', () {
      expect(splitByExactAmounts(500, {'a': 500, 'b': 0}),
          {'a': 500, 'b': 0});
    });

    test('mismatch throws typed error with both totals', () {
      expect(
        () => splitByExactAmounts(1000, {'a': 250, 'b': 700}),
        throwsA(isA<ExactAmountsMismatchError>()
            .having((e) => e.expectedTotal, 'expected', 1000)
            .having((e) => e.actualTotal, 'actual', 950)),
      );
    });

    test('negative amount throws', () {
      expect(() => splitByExactAmounts(100, {'a': 150, 'b': -50}),
          throwsA(isA<NegativeAmountError>()));
    });

    test('empty throws', () {
      expect(() => splitByExactAmounts(0, {}),
          throwsA(isA<EmptyParticipantsError>()));
    });
  });

  group('splitByPercentages', () {
    test('simple percentages', () {
      expect(splitByPercentages(2000, {'a': 50, 'b': 25, 'c': 25}),
          {'a': 1000, 'b': 500, 'c': 500});
    });

    test('thirds with remainder', () {
      final r = splitByPercentages(
          100, {'a': 100 / 3, 'b': 100 / 3, 'c': 100 / 3});
      expect(r, {'a': 34, 'b': 33, 'c': 33});
    });

    test('fractional percentages sum exactly', () {
      final r = splitByPercentages(9999, {'a': 12.5, 'b': 37.5, 'c': 50});
      expect(_sum(r), 9999);
      // quotas 1249.875 / 3749.625 / 4999.5 -> floors sum to 9997; the two
      // leftover units go to the largest fractions (a: .875, b: .625).
      expect(r, {'a': 1250, 'b': 3750, 'c': 4999});
    });

    test('must sum to 100', () {
      expect(() => splitByPercentages(100, {'a': 50, 'b': 40}),
          throwsA(isA<PercentagesMismatchError>()));
      expect(() => splitByPercentages(100, {'a': 60, 'b': 50}),
          throwsA(isA<PercentagesMismatchError>()));
    });

    test('negative percentage throws', () {
      expect(() => splitByPercentages(100, {'a': 110, 'b': -10}),
          throwsA(isA<NegativeAmountError>()));
    });
  });

  group('splitByShares', () {
    test('integer shares', () {
      expect(splitByShares(1000, {'adult1': 2, 'adult2': 2, 'kid': 1}),
          {'adult1': 400, 'adult2': 400, 'kid': 200});
    });

    test('fractional shares', () {
      expect(splitByShares(1000, {'a': 1.5, 'b': 0.5}),
          {'a': 750, 'b': 250});
    });

    test('remainders distributed deterministically', () {
      final r = splitByShares(1001, {'a': 1, 'b': 1});
      expect(r, {'a': 501, 'b': 500});
    });

    test('works with zero-decimal currency amounts (JPY)', () {
      expect(splitByShares(1000, {'a': 1, 'b': 1, 'c': 1}),
          {'a': 334, 'b': 333, 'c': 333});
    });

    test('validation', () {
      expect(() => splitByShares(100, {'a': 0, 'b': 0}),
          throwsA(isA<ZeroTotalWeightError>()));
      expect(() => splitByShares(100, {'a': -1, 'b': 2}),
          throwsA(isA<NegativeAmountError>()));
      expect(() => splitByShares(100, {'a': double.nan}),
          throwsA(isA<InvalidAmountError>()));
    });
  });
}
