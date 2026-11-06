import 'package:flutter/foundation.dart';

/// Disposes [notifiers] once a dialog that used them has finished closing.
///
/// `await showDialog(...)` returns when the route starts popping; its fields
/// keep listening through the exit animation, so disposing right away throws
/// "A TextEditingController was used after being disposed".
// shortcut: fixed delay longer than any dialog/sheet exit animation (~300 ms);
// switch to a StatefulWidget-owned controller if a route ever animates longer.
void disposeAfterRouteCloses(Iterable<ChangeNotifier> notifiers) {
  final list = List.of(notifiers);
  Future<void>.delayed(const Duration(milliseconds: 600), () {
    for (final n in list) {
      n.dispose();
    }
  });
}
