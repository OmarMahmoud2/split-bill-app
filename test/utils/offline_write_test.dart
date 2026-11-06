import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/utils/offline_write.dart';

const _short = Duration(milliseconds: 20);

void main() {
  test('an acknowledged write is committed', () async {
    expect(await commitOrQueue(Future<void>.value()), WriteOutcome.committed);
  });

  test('a write that never completes (offline) is queued, not hung', () async {
    expect(
      await commitOrQueue(Completer<void>().future, timeout: _short),
      WriteOutcome.queued,
    );
  });

  test('real failures are rethrown', () async {
    await expectLater(
      commitOrQueue(Future<void>.error(StateError('permission-denied'))),
      throwsA(isA<StateError>()),
    );
  });

  test('an error after the timeout reaches onLateError', () async {
    final c = Completer<void>();
    Object? late;
    final outcome = await commitOrQueue(
      c.future,
      timeout: _short,
      onLateError: (e) => late = e,
    );
    expect(outcome, WriteOutcome.queued);
    c.completeError(StateError('denied'));
    await Future<void>.delayed(Duration.zero);
    expect(late, isA<StateError>());
  });
}
