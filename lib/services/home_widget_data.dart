/// Pure data layer for the home-screen widgets (no Flutter, Firebase or
/// platform channels), so balances, formatting and widget routes can be
/// unit tested.
///
/// The native widgets (iOS WidgetKit, Android AppWidgetProvider) only display
/// what is computed here: every label and amount arrives pre-localized and
/// pre-formatted in a single JSON payload. See docs/2.0/WIDGETS.md.
library;

import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/utils/currency_utils.dart';

/// Payload schema version understood by the native widgets.
const int widgetPayloadVersion = 1;

/// Key under which the JSON payload is stored in the shared widget storage
/// (App Group UserDefaults on iOS, HomeWidgetPreferences on Android).
const String widgetPayloadKey = 'sb_widget_payload';

/// How many counterparts the "Settle with" widget lists.
const int widgetTopPeopleCount = 3;

/// URL scheme registered by the app (ios/Runner/Info.plist) and used by all
/// widget tap targets.
const String widgetUriScheme = 'splitbill';
const String widgetUriHost = 'widget';

/// Unicode left-to-right isolate, so "+$62.40" keeps its shape inside an RTL
/// (Arabic, Urdu) widget.
const String _lri = '\u2066';
const String _pdi = '\u2069';

/// Real minus sign, as in the design spec ("-24.00").
const String _minus = '\u2212';

/// Statuses that mean a share is still open (mirrors HomeScreen totals).
const Set<String> _openStatuses = {'PENDING', 'REVIEW'};

/// Localized strings the widgets show. Built from translation keys in the
/// app (`widget_*` in assets/translations) by [HomeWidgetService].
class WidgetStrings {
  const WidgetStrings({
    required this.youAreOwed,
    required this.youOwe,
    required this.allSettled,
    required this.updatedAt,
    required this.scanReceipt,
    required this.settleWith,
    required this.noOpenBalances,
    required this.signInPrompt,
    required this.hideAmounts,
    required this.showAmounts,
  });

  final String youAreOwed;
  final String youOwe;
  final String allSettled;

  /// Already includes the formatted time ("Updated 14:32").
  final String updatedAt;
  final String scanReceipt;
  final String settleWith;
  final String noOpenBalances;
  final String signInPrompt;
  final String hideAmounts;
  final String showAmounts;

  Map<String, String> toJson() => {
    'youAreOwed': youAreOwed,
    'youOwe': youOwe,
    'allSettled': allSettled,
    'updatedAt': updatedAt,
    'scan': scanReceipt,
    'settleWith': settleWith,
    'noBalances': noOpenBalances,
    'signIn': signInPrompt,
    'hide': hideAmounts,
    'show': showAmounts,
  };
}

/// Net position with one other person across all open bills.
class WidgetCounterpart {
  const WidgetCounterpart({
    required this.id,
    required this.name,
    required this.netMinor,
    this.billId,
  });

  /// Participant id (Firebase uid, or a local id for contacts without app).
  final String id;
  final String name;

  /// Positive: they owe me. Negative: I owe them. Minor units.
  final int netMinor;

  /// The open bill with the largest share between us; the row deep-links to
  /// it, which is where settling happens today.
  final String? billId;
}

/// Balances for the signed-in member, in minor units of one currency.
class WidgetBalances {
  const WidgetBalances({
    required this.currency,
    required this.owedToMeMinor,
    required this.iOweMinor,
    required this.counterparts,
  });

  final String currency;
  final int owedToMeMinor;
  final int iOweMinor;

  /// Everyone with a non-zero net, largest absolute amount first.
  final List<WidgetCounterpart> counterparts;

  int get netMinor => owedToMeMinor - iOweMinor;

  List<WidgetCounterpart> get top =>
      counterparts.take(widgetTopPeopleCount).toList();
}

class _Accumulator {
  _Accumulator(this.id, this.name);

  final String id;
  String name;
  int netMinor = 0;
  String? billId;
  int billShareMinor = 0;

  void add(int signedMinor, String billId) {
    netMinor += signedMinor;
    if (signedMinor.abs() > billShareMinor) {
      billShareMinor = signedMinor.abs();
      this.billId = billId;
    }
  }
}

/// Computes balances from raw `bills` documents, using exactly the rules of
/// `HomeScreen._calculateTotals` so the widget and the home header agree:
/// as host, every other participant whose share is PENDING/REVIEW owes me;
/// as participant, my own PENDING/REVIEW share is owed to the host.
///
/// Shares are converted to integer minor units of [currency] before summing.
/// [bills] maps bill id to the document data.
WidgetBalances computeWidgetBalances({
  required Map<String, Map<String, dynamic>> bills,
  required String uid,
  required String currency,
}) {
  final code = normalizeCurrency(currency);
  var owedToMe = 0;
  var iOwe = 0;
  final people = <String, _Accumulator>{};

  int minorOf(Object? share) {
    final value = (share is num) ? share.toDouble() : 0.0;
    if (value.isNaN || value.isInfinite || value <= 0) return 0;
    return toMinorUnits(value, code);
  }

  String nameOf(Map participant) {
    final name = participant['name'];
    return (name is String && name.trim().isNotEmpty) ? name.trim() : '?';
  }

  for (final entry in bills.entries) {
    final data = entry.value;
    final participants = (data['participants'] as List?) ?? const [];
    final hostId = data['hostId'];

    if (hostId == uid) {
      for (final p in participants) {
        if (p is! Map) continue;
        final id = p['id'];
        if (id == null || id == uid) continue;
        if (!_openStatuses.contains(p['status'])) continue;
        final minor = minorOf(p['share']);
        if (minor == 0) continue;
        owedToMe += minor;
        people
            .putIfAbsent('$id', () => _Accumulator('$id', nameOf(p)))
            .add(minor, entry.key);
      }
    } else {
      Map? me;
      Map? host;
      for (final p in participants) {
        if (p is! Map) continue;
        if (p['id'] == uid) me = p;
        if (p['id'] == hostId) host = p;
      }
      if (me == null || !_openStatuses.contains(me['status'])) continue;
      final minor = minorOf(me['share']);
      if (minor == 0) continue;
      iOwe += minor;
      if (hostId == null) continue;
      final hostName = host != null
          ? nameOf(host)
          : ((data['hostName'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['hostName'] as String).trim()
          : '?';
      people
          .putIfAbsent('$hostId', () => _Accumulator('$hostId', hostName))
          .add(-minor, entry.key);
    }
  }

  final counterparts =
      people.values
          .where((a) => a.netMinor != 0)
          .map(
            (a) => WidgetCounterpart(
              id: a.id,
              name: a.name,
              netMinor: a.netMinor,
              billId: a.billId,
            ),
          )
          .toList()
        ..sort((a, b) {
          final byAmount = b.netMinor.abs().compareTo(a.netMinor.abs());
          return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
        });

  return WidgetBalances(
    currency: code,
    owedToMeMinor: owedToMe,
    iOweMinor: iOwe,
    counterparts: counterparts,
  );
}

/// "+$62.40", "-$12.00", "$0.00" with the currency's own decimals
/// (JPY 0, KWD 3), wrapped in an LTR isolate.
///
/// Uses the short currency symbol (as in the design) because the small
/// widget has little room; codes without a symbol fall back to the code.
String formatSignedMoney(int minor, String currency, String locale) {
  final code = normalizeCurrency(currency);
  final decimals = currencyDecimals(code);
  final amount = fromMinorUnits(minor.abs(), code);
  String? formatted;
  try {
    final simple = NumberFormat.simpleCurrency(
      locale: locale,
      name: code,
      decimalDigits: decimals,
    );
    // Only real symbols ($, €, ¥, ₹...); "din" or "E£" read worse than the
    // ISO code the rest of the app shows.
    if (!simple.currencySymbol.contains(RegExp('[A-Za-z]'))) {
      formatted = simple.format(amount);
    }
  } catch (_) {
    formatted = null;
  }
  formatted ??= CurrencyUtils.format(
    amount,
    currencyCode: code,
    localeCode: locale,
    decimalDigits: decimals,
  );
  return '$_lri${_signPrefix(minor)}$formatted$_pdi';
}

/// "+54.10" / "-24.00" without a currency symbol (rows of the medium widget,
/// as in the design), using the currency's decimals.
String formatSignedAmount(int minor, String currency, String locale) {
  final code = normalizeCurrency(currency);
  final decimals = currencyDecimals(code);
  String formatted;
  try {
    formatted = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimals,
    ).format(fromMinorUnits(minor.abs(), code));
  } catch (_) {
    formatted = fromMinorUnits(minor.abs(), code).toStringAsFixed(decimals);
  }
  return '$_lri${_signPrefix(minor)}$formatted$_pdi';
}

String _signPrefix(int minor) => minor > 0
    ? '+'
    : minor < 0
    ? _minus
    : '';

int _sign(int minor) => minor.sign;

/// Whether [languageCode] is written right to left (ar, ur, ...).
bool isRtlLanguage(String languageCode) => Bidi.isRtlLanguage(languageCode);

/// Builds the JSON payload the native widgets render.
///
/// [balances] null means signed out (or an anonymous guest): the widgets
/// then show [WidgetStrings.signInPrompt] and no amounts.
String buildWidgetPayload({
  required WidgetBalances? balances,
  required WidgetStrings strings,
  required String locale,
}) {
  final languageCode = locale.split(RegExp('[-_]')).first;
  final payload = <String, Object?>{
    'v': widgetPayloadVersion,
    'state': balances == null ? 'signedOut' : 'ready',
    'locale': locale,
    'dir': isRtlLanguage(languageCode) ? 'rtl' : 'ltr',
    'strings': strings.toJson(),
    'scanUrl': WidgetRoute.scan.toUri().toString(),
    'homeUrl': WidgetRoute.home.toUri().toString(),
  };

  if (balances != null) {
    final net = balances.netMinor;
    final top = balances.top;
    payload['balance'] = {
      'label': net > 0
          ? strings.youAreOwed
          : net < 0
          ? strings.youOwe
          : strings.allSettled,
      'amount': formatSignedMoney(net, balances.currency, locale),
      'sign': _sign(net),
      // Major units for SwiftUI's numericText(value:) transition.
      'value': fromMinorUnits(net, balances.currency),
      'count': balances.counterparts.length,
      'currency': balances.currency,
    };
    payload['people'] = [
      for (final person in top)
        {
          'id': person.id,
          'name': person.name,
          'amount': formatSignedAmount(
            person.netMinor,
            balances.currency,
            locale,
          ),
          'sign': _sign(person.netMinor),
          'url': WidgetRoute.friend(
            person.id,
            billId: person.billId,
          ).toUri().toString(),
        },
    ];
  }
  return jsonEncode(payload);
}

enum WidgetRouteKind { home, scan, friend }

/// A destination reachable from a widget tap.
///
/// URIs look like `splitbill://widget/scan?homeWidget`; the `homeWidget`
/// query parameter is what home_widget's iOS plugin uses to recognize widget
/// launches.
class WidgetRoute {
  const WidgetRoute._(this.kind, {this.friendId, this.billId});

  static const home = WidgetRoute._(WidgetRouteKind.home);
  static const scan = WidgetRoute._(WidgetRouteKind.scan);

  factory WidgetRoute.friend(String friendId, {String? billId}) =>
      WidgetRoute._(WidgetRouteKind.friend, friendId: friendId, billId: billId);

  final WidgetRouteKind kind;
  final String? friendId;
  final String? billId;

  Uri toUri() {
    final query = <String, String>{
      if (friendId != null) 'id': friendId!,
      if (billId != null) 'billId': billId!,
      'homeWidget': '',
    };
    // Uri drops the "=" for empty values only when built by hand.
    final queryString = query.entries
        .map(
          (e) => e.value.isEmpty
              ? Uri.encodeQueryComponent(e.key)
              : '${Uri.encodeQueryComponent(e.key)}='
                    '${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return Uri.parse(
      '$widgetUriScheme://$widgetUriHost/${kind.name}?$queryString',
    );
  }

  /// Parses a widget URI; returns null for anything that is not one (bill
  /// share links, other schemes), so callers can fall through to their
  /// existing deep-link handling.
  static WidgetRoute? tryParse(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != widgetUriScheme) return null;
    if (uri.host.toLowerCase() != widgetUriHost) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final name = segments.isEmpty ? 'home' : segments.first.toLowerCase();
    switch (name) {
      case 'home':
      case 'balance':
        return home;
      case 'scan':
        return scan;
      case 'friend':
        final id = uri.queryParameters['id'];
        if (id == null || id.isEmpty) return home;
        final billId = uri.queryParameters['billId'];
        return WidgetRoute.friend(
          id,
          billId: (billId == null || billId.isEmpty) ? null : billId,
        );
      default:
        return home;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is WidgetRoute &&
      other.kind == kind &&
      other.friendId == friendId &&
      other.billId == billId;

  @override
  int get hashCode => Object.hash(kind, friendId, billId);

  @override
  String toString() => 'WidgetRoute(${kind.name}, $friendId, $billId)';
}

/// Drops the same widget URI delivered twice in quick succession (iOS can
/// hand it to both home_widget and app_links; Android to both on cold start).
class WidgetLaunchDeduper {
  WidgetLaunchDeduper({
    this.window = const Duration(seconds: 2),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration window;
  final DateTime Function() _clock;
  Uri? _lastUri;
  DateTime? _lastAt;

  bool shouldHandle(Uri uri) {
    final now = _clock();
    final duplicate =
        _lastUri == uri && _lastAt != null && now.difference(_lastAt!) < window;
    _lastUri = uri;
    _lastAt = now;
    return !duplicate;
  }
}
