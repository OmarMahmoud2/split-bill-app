/// Splitting a total (in integer minor units) among participants.
///
/// Every function returns an insertion-ordered `Map<participantId, minor>`
/// whose values always sum exactly to the total. Leftover minor units are
/// handed out with the largest-remainder (Hamilton) method; ties are broken
/// by the participants' input order, so results are fully deterministic.
library;

import 'domain_errors.dart';

/// Fixed-point scale used to turn fractional weights (percentages, 1.5
/// shares) into exact integers before allocation.
const int _weightScale = 1000000;

/// Tolerance when checking that percentages sum to 100.
const double _percentTolerance = 1e-6;

/// Splits [total] proportionally to integer [weights] using the
/// largest-remainder method.
///
/// Each participant first gets `floor(total * w / W)`; the remaining units
/// go one each to the participants with the largest fractional remainder,
/// earliest-listed first on ties.
Map<String, int> allocateByWeights(int total, Map<String, int> weights) {
  if (weights.isEmpty) throw const EmptyParticipantsError();
  if (total < 0) throw NegativeAmountError('total', total);
  var weightSum = 0;
  for (final entry in weights.entries) {
    if (entry.value < 0) throw NegativeAmountError(entry.key, entry.value);
    weightSum += entry.value;
  }
  if (weightSum == 0) throw const ZeroTotalWeightError();

  // BigInt keeps total * weight exact for very large amounts.
  final bigTotal = BigInt.from(total);
  final bigSum = BigInt.from(weightSum);
  final keys = weights.keys.toList(growable: false);
  final base = <int>[];
  final remainders = <BigInt>[];
  var allocated = 0;
  for (final key in keys) {
    final product = bigTotal * BigInt.from(weights[key]!);
    final share = (product ~/ bigSum).toInt();
    base.add(share);
    remainders.add(product.remainder(bigSum));
    allocated += share;
  }

  final order = List<int>.generate(keys.length, (i) => i)
    ..sort((a, b) {
      final byRemainder = remainders[b].compareTo(remainders[a]);
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  var leftover = total - allocated;
  for (var i = 0; leftover > 0; i++, leftover--) {
    base[order[i]] += 1;
  }

  return {for (var i = 0; i < keys.length; i++) keys[i]: base[i]};
}

void _checkParticipants(Iterable<String> participants) {
  if (participants.isEmpty) throw const EmptyParticipantsError();
  final seen = <String>{};
  for (final p in participants) {
    if (!seen.add(p)) throw DuplicateParticipantError(p);
  }
}

int _scaleWeight(String key, num value) {
  if (value is double && (value.isNaN || value.isInfinite)) {
    throw InvalidAmountError(value);
  }
  if (value < 0) throw NegativeAmountError(key, value);
  return (value * _weightScale).round();
}

/// Splits [total] equally; the first participants absorb leftover units
/// (1000 among 3 -> 334, 333, 333).
Map<String, int> splitEqually(int total, List<String> participants) {
  _checkParticipants(participants);
  return allocateByWeights(total, {for (final p in participants) p: 1});
}

/// Validates that explicit [amounts] add up to [total] and returns them.
Map<String, int> splitByExactAmounts(int total, Map<String, int> amounts) {
  if (amounts.isEmpty) throw const EmptyParticipantsError();
  if (total < 0) throw NegativeAmountError('total', total);
  var sum = 0;
  for (final entry in amounts.entries) {
    if (entry.value < 0) throw NegativeAmountError(entry.key, entry.value);
    sum += entry.value;
  }
  if (sum != total) {
    throw ExactAmountsMismatchError(expectedTotal: total, actualTotal: sum);
  }
  return Map<String, int>.of(amounts);
}

/// Splits [total] by [percentages], which must be >= 0 and sum to 100
/// (within 1e-6, so 100/3 three times is accepted).
Map<String, int> splitByPercentages(int total, Map<String, num> percentages) {
  if (percentages.isEmpty) throw const EmptyParticipantsError();
  final weights = <String, int>{};
  num sum = 0;
  for (final entry in percentages.entries) {
    weights[entry.key] = _scaleWeight(entry.key, entry.value);
    sum += entry.value;
  }
  if ((sum - 100).abs() > _percentTolerance) {
    throw PercentagesMismatchError(sum);
  }
  return allocateByWeights(total, weights);
}

/// Splits [total] by relative [shares]/weights (e.g. adults 2, kids 1).
/// Fractional shares are supported with 6 decimal places of precision.
Map<String, int> splitByShares(int total, Map<String, num> shares) {
  if (shares.isEmpty) throw const EmptyParticipantsError();
  return allocateByWeights(total, {
    for (final entry in shares.entries)
      entry.key: _scaleWeight(entry.key, entry.value),
  });
}
