/// Turns bill `history` entries into localized lines ("You changed Kunafa
/// from 6.00 to 7.00 · 2 h ago") and formats relative times.
///
/// Everything here is pure: translation goes through a [Translate]
/// function (defaults to easy_localization) so tests can check the key and
/// the arguments without loading translations.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/utils/money_format.dart';

/// Looks up [key] with named [args].
typedef Translate = String Function(String key, Map<String, String> args);

String trTranslate(String key, Map<String, String> args) =>
    key.tr(namedArgs: args);

// --------------------------------------------------------------- relative time

enum RelativeUnit { justNow, minutes, hours, days, date }

/// A relative time, before localization.
class RelativeTime {
  const RelativeTime(this.unit, {this.count = 0, required this.at});

  final RelativeUnit unit;
  final int count;

  /// The original time (used for [RelativeUnit.date]).
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is RelativeTime && other.unit == unit && other.count == count;

  @override
  int get hashCode => Object.hash(unit, count);

  @override
  String toString() => 'RelativeTime($unit, $count)';
}

/// How long ago [at] was, seen from [now]. Future times (clock skew) read
/// as "just now". Up to 6 days it is relative, after that a date.
RelativeTime relativeTimeOf(DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inSeconds < 60) return RelativeTime(RelativeUnit.justNow, at: at);
  if (diff.inMinutes < 60) {
    return RelativeTime(RelativeUnit.minutes, count: diff.inMinutes, at: at);
  }
  if (diff.inHours < 24) {
    return RelativeTime(RelativeUnit.hours, count: diff.inHours, at: at);
  }
  if (diff.inDays < 7) {
    return RelativeTime(RelativeUnit.days, count: diff.inDays, at: at);
  }
  return RelativeTime(RelativeUnit.date, at: at);
}

/// Localized label for [time]: "just now", "5 min ago", "2 h ago",
/// "3 d ago", or a short date ("28 Oct").
String formatRelativeTime(
  RelativeTime time, {
  Translate translate = trTranslate,
  String? locale,
  DateTime? now,
}) {
  switch (time.unit) {
    case RelativeUnit.justNow:
      return translate('bf_edit_time_just_now', const {});
    case RelativeUnit.minutes:
      return translate('bf_edit_time_minutes', {'count': '${time.count}'});
    case RelativeUnit.hours:
      return translate('bf_edit_time_hours', {'count': '${time.count}'});
    case RelativeUnit.days:
      return translate('bf_edit_time_days', {'count': '${time.count}'});
    case RelativeUnit.date:
      final sameYear = time.at.year == (now ?? DateTime.now()).year;
      final loc = safeDateLocale(locale);
      return sameYear
          ? DateFormat.MMMd(loc).format(time.at)
          : DateFormat.yMMMd(loc).format(time.at);
  }
}

/// [locale] when its date symbols are loaded, else null (default locale),
/// so formatting never throws for a locale without date data.
String? safeDateLocale(String? locale) {
  if (locale == null) return null;
  try {
    if (DateFormat.localeExists(locale)) return locale;
    final lang = locale.split(RegExp('[-_]')).first;
    return DateFormat.localeExists(lang) ? lang : null;
  } catch (_) {
    return null;
  }
}

/// Shortcut: [formatRelativeTime] of [relativeTimeOf].
String relativeTimeLabel(
  DateTime at,
  DateTime now, {
  Translate translate = trTranslate,
  String? locale,
}) => formatRelativeTime(
  relativeTimeOf(at, now),
  translate: translate,
  locale: locale,
  now: now,
);

// --------------------------------------------------------------- history lines

/// One rendered history line: a bold [author] and the [action] after it.
class HistoryLine {
  const HistoryLine({required this.author, required this.action});

  final String author;
  final String action;

  @override
  String toString() => '$author $action';
}

/// Every change code with a template. Anything else renders as "edited".
const Set<String> kHistoryChangeCodes = {
  'created',
  'edited',
  'renamed',
  'item_price',
  'item_added',
  'item_removed',
  'person_added',
  'person_removed',
  'charges',
  'split_method',
  'currency',
  'marked_paid',
};

/// Translation key for a split method wire name.
String splitMethodKey(String wireName) => switch (wireName) {
  'equal' => 'bf_edit_method_equal',
  'exact' => 'bf_edit_method_exact',
  'percent' => 'bf_edit_method_percent',
  'shares' => 'bf_edit_method_shares',
  _ => 'bf_edit_method_items',
};

String _s(Object? v) => v?.toString() ?? '';

/// Renders [entry]. The author is "You" when it is [currentUid], else the
/// stored name (or "Someone"). Money args (minor units) are formatted in
/// [currency] without a symbol, like the board ("6.00 to 7.00").
HistoryLine describeHistoryEntry(
  BillHistoryEntry entry, {
  required String? currentUid,
  required String currency,
  Translate translate = trTranslate,
  String? locale,
}) {
  final isMe = currentUid != null && entry.by == currentUid;
  final name = (entry.byName ?? '').trim();
  final author = isMe
      ? translate('bf_edit_history_you', const {})
      : name.isNotEmpty
      ? name
      : translate('bf_edit_history_someone', const {});

  String money(Object? minor) {
    final value = minor is num ? minor.round() : int.tryParse(_s(minor));
    if (value == null) return _s(minor);
    return formatMoneyMinor(value, currency, showSymbol: false, locale: locale);
  }

  final a = entry.args;
  final change = kHistoryChangeCodes.contains(entry.change)
      ? entry.change
      : 'edited';
  final String action;
  switch (change) {
    case 'renamed':
      action = translate('bf_edit_history_renamed', {
        'from': _s(a['from']),
        'to': _s(a['to']),
      });
    case 'item_price':
      action = translate('bf_edit_history_item_price', {
        'item': _s(a['item']),
        'from': money(a['from']),
        'to': money(a['to']),
      });
    case 'item_added':
      action = a['to'] == null
          ? translate('bf_edit_history_item_added_plain', {
              'item': _s(a['item']),
            })
          : translate('bf_edit_history_item_added', {
              'item': _s(a['item']),
              'amount': money(a['to']),
            });
    case 'item_removed':
      action = translate('bf_edit_history_item_removed', {
        'item': _s(a['item']),
      });
    case 'person_added':
      action = translate('bf_edit_history_person_added', {
        'name': _s(a['name']),
      });
    case 'person_removed':
      action = translate('bf_edit_history_person_removed', {
        'name': _s(a['name']),
      });
    case 'charges':
      action = translate('bf_edit_history_charges', {
        'from': money(a['from']),
        'to': money(a['to']),
      });
    case 'split_method':
      action = translate('bf_edit_history_split_method', {
        'from': translate(splitMethodKey(_s(a['from'])), const {}),
        'to': translate(splitMethodKey(_s(a['to'])), const {}),
      });
    case 'currency':
      action = translate('bf_edit_history_currency', {
        'from': _s(a['from']),
        'to': _s(a['to']),
      });
    case 'marked_paid':
      final who = _s(a['name']).trim();
      final self =
          who.isEmpty ||
          (a['id'] != null && _s(a['id']) == entry.by) ||
          (name.isNotEmpty && who == name);
      action = self
          ? translate('bf_edit_history_marked_paid_self', const {})
          : translate('bf_edit_history_marked_paid', {'name': who});
    case 'created':
      action = translate('bf_edit_history_created', const {});
    default:
      action = translate('bf_edit_history_edited', const {});
  }
  return HistoryLine(author: author, action: action);
}
