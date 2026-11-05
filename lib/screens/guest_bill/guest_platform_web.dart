/// Web implementation of the guest browser helpers.
library;

import 'dart:js_interop';

@JS('navigator.userAgent')
external String get _userAgent;

@JS('navigator.maxTouchPoints')
external int? get _maxTouchPoints;

final _otherIosBrowsers = RegExp('CriOS|FxiOS|EdgiOS|OPiOS|GSA/|DuckDuckGo');

/// Whether the page runs in Safari on an iPhone or iPad (iPadOS reports a
/// Mac user agent, so touch support tells them apart).
bool get isIosSafari {
  final ua = _userAgent;
  final ios =
      RegExp('iPhone|iPad|iPod').hasMatch(ua) ||
      (ua.contains('Macintosh') && (_maxTouchPoints ?? 0) > 1);
  return ios && ua.contains('Safari') && !_otherIosBrowsers.hasMatch(ua);
}
