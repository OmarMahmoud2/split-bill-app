import 'dart:async';

/// How a Firestore write finished.
enum WriteOutcome {
  /// The server acknowledged it.
  committed,

  /// No acknowledgement within the timeout (usually offline). Firestore keeps
  /// the write queued on the device and syncs it once the connection is back.
  queued,
}

/// Awaits [write] for at most [timeout].
///
/// Real failures (permission denied, invalid data) are rethrown. A timeout is
/// not a failure: offline, Firestore's local write succeeds but the server
/// acknowledgement never arrives, so the future just hangs. [onLateError]
/// receives an error that surfaces after the timeout.
Future<WriteOutcome> commitOrQueue(
  Future<void> write, {
  Duration timeout = const Duration(seconds: 6),
  void Function(Object error)? onLateError,
}) async {
  var timedOut = false;
  final guarded = write.catchError((Object e) {
    if (timedOut) {
      onLateError?.call(e);
      return;
    }
    throw e;
  });
  try {
    await guarded.timeout(timeout);
    return WriteOutcome.committed;
  } on TimeoutException {
    timedOut = true;
    return WriteOutcome.queued;
  }
}
