import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/utils/offline_write.dart';

void main() {
  test('an acknowledged write is committed', () async {
    expect(await commitOrQueue(Future<void>.value()), WriteOutcome.committed);
  });

  test('a write that never completes (offline) is queued, not hung', () {
    fakeAsync((async) {
      WriteOutcome? outcome;
      commitOrQueue(Completer<void>().future).then((o) => outcome = o);
      async.elapse(const Duration(seconds: 7));
      expect(outcome, WriteOutcome.queued);
    });
  });

  test('real failures are rethrown', () async {
    await expectLater(
      commitOrQueue(Future<void>.error(StateError('permission-denied'))),
      throwsA(isA<StateError>()),
    );
  });

  test('an error after the timeout reaches onLateError', () {
    fakeAsync((async) {
      final c = Completer<void>();
      Object? late;
      commitOrQueue(c.future, onLateError: (e) => late = e);
      async.elapse(const Duration(seconds: 7));
      c.completeError(StateError('denied'));
      async.flushMicrotasks();
      expect(late, isA<StateError>());
    });
  });
}
