/// Typed errors raised by the pure-Dart domain layer.
///
/// Every error extends [DomainError], so callers can catch the whole family
/// with a single `on DomainError` clause, or match a specific subtype.
library;

sealed class DomainError implements Exception {
  const DomainError();

  /// Human readable (developer facing, not localized) description.
  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

/// An amount was NaN, infinite or otherwise unusable.
class InvalidAmountError extends DomainError {
  final Object? value;
  const InvalidAmountError(this.value);

  @override
  String get message => 'Invalid amount: $value';
}

/// A negative value was supplied where only values >= 0 are allowed.
class NegativeAmountError extends DomainError {
  final String field;
  final num value;
  const NegativeAmountError(this.field, this.value);

  @override
  String get message => '$field must not be negative (got $value)';
}

/// Two amounts in different currencies were combined.
class CurrencyMismatchError extends DomainError {
  final String expected;
  final String actual;
  const CurrencyMismatchError(this.expected, this.actual);

  @override
  String get message => 'Currency mismatch: expected $expected, got $actual';
}

/// A split needs at least one participant.
class EmptyParticipantsError extends DomainError {
  const EmptyParticipantsError();

  @override
  String get message => 'At least one participant is required';
}

/// The same participant id appears more than once.
class DuplicateParticipantError extends DomainError {
  final String participantId;
  const DuplicateParticipantError(this.participantId);

  @override
  String get message => 'Duplicate participant: $participantId';
}

/// A participant id was referenced that is not part of the split.
class UnknownParticipantError extends DomainError {
  final String participantId;
  const UnknownParticipantError(this.participantId);

  @override
  String get message => 'Unknown participant: $participantId';
}

/// Exact amounts did not add up to the bill total.
class ExactAmountsMismatchError extends DomainError {
  final int expectedTotal;
  final int actualTotal;
  const ExactAmountsMismatchError({
    required this.expectedTotal,
    required this.actualTotal,
  });

  @override
  String get message =>
      'Exact amounts sum to $actualTotal but the total is $expectedTotal';
}

/// Percentages did not add up to 100.
class PercentagesMismatchError extends DomainError {
  final num actualSum;
  const PercentagesMismatchError(this.actualSum);

  @override
  String get message => 'Percentages must sum to 100 (got $actualSum)';
}

/// All weights/shares were zero, so there is nothing to split by.
class ZeroTotalWeightError extends DomainError {
  const ZeroTotalWeightError();

  @override
  String get message => 'The sum of shares/weights must be greater than 0';
}

/// An item is not (or over-) assigned.
class ItemAssignmentError extends DomainError {
  final String itemName;
  final int quantity;
  final int assignedQuantity;
  const ItemAssignmentError({
    required this.itemName,
    required this.quantity,
    required this.assignedQuantity,
  });

  @override
  String get message =>
      'Item "$itemName" has $assignedQuantity of $quantity units assigned';
}

/// What was paid for an expense does not match what is owed for it.
class UnbalancedExpenseError extends DomainError {
  final String expenseId;
  final int paidTotal;
  final int owedTotal;
  const UnbalancedExpenseError({
    required this.expenseId,
    required this.paidTotal,
    required this.owedTotal,
  });

  @override
  String get message =>
      'Expense $expenseId: paid $paidTotal but owed $owedTotal';
}

/// Net balances in one currency do not sum to zero.
class UnbalancedBalancesError extends DomainError {
  final String currency;
  final int sum;
  const UnbalancedBalancesError(this.currency, this.sum);

  @override
  String get message => 'Balances in $currency sum to $sum instead of 0';
}

/// A payment from a person to themselves.
class SelfPaymentError extends DomainError {
  final String participantId;
  const SelfPaymentError(this.participantId);

  @override
  String get message => '$participantId cannot pay themselves';
}

/// The same record id was reused with different content.
class ConflictingRecordError extends DomainError {
  final String id;
  const ConflictingRecordError(this.id);

  @override
  String get message => 'Record $id already exists with different content';
}
