/// Builds the review banner ("Printed total 81.27 matches. Check 'Kunafa',
/// the photo was blurry there.") from the scan's `needs_review_reasons`,
/// `reconciliation` and per-item confidence.
///
/// Pure: returns translation keys plus named args, so it is unit tested
/// without easy_localization and the widget only translates.
library;

import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/utils/money_format.dart';

/// Below this item confidence a line is highlighted for review.
const double kReviewConfidenceThreshold = 0.78;

enum ReviewBannerTone {
  /// Something needs a look: amber (oweSoft / oweInk).
  warning,

  /// All checks passed: calm teal.
  calm,
}

class ReviewNote {
  const ReviewNote(this.key, [this.args = const {}]);

  final String key;
  final Map<String, String> args;

  @override
  bool operator ==(Object other) =>
      other is ReviewNote &&
      other.key == key &&
      other.args.length == args.length &&
      other.args.entries.every((e) => args[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    key,
    Object.hashAllUnordered(args.entries.map((e) => '${e.key}=${e.value}')),
  );

  @override
  String toString() => 'ReviewNote($key, $args)';
}

class ReviewBannerContent {
  const ReviewBannerContent({
    required this.tone,
    required this.notes,
    required this.flaggedItemIndexes,
  });

  final ReviewBannerTone tone;
  final List<ReviewNote> notes;

  /// Item rows to highlight.
  final Set<int> flaggedItemIndexes;

  /// The banner sentence, translating each note with [translate].
  String text(
    String Function(String key, Map<String, String> args) translate,
  ) => notes.map((n) => translateReviewNote(n, translate)).join(' ');
}

/// Reason codes we know how to explain. Matching is by substring so
/// `blurry_item`, `item_blurry` and `BLURRY` all land on the same copy.
const List<(String, String)> _reasonCopy = [
  ('handwrit', 'bf_scan_review_handwritten'),
  ('cut', 'bf_scan_review_cut_off'),
  ('partial', 'bf_scan_review_cut_off'),
  ('currency', 'bf_scan_review_currency'),
  ('date', 'bf_scan_review_date'),
  ('no_total', 'bf_scan_review_no_total'),
  ('missing_total', 'bf_scan_review_no_total'),
  ('total_not_found', 'bf_scan_review_no_total'),
];

bool _isBlurry(String code) => code.contains('blur');

bool _isTotalMismatch(String code) =>
    code.contains('mismatch') ||
    code.contains('total_diff') ||
    code.contains('reconcil');

bool _looksLikeSentence(String s) => s.trim().contains(' ');

Object? _pick(Map<dynamic, dynamic> map, List<String> keys) {
  for (final k in keys) {
    if (map.containsKey(k) && map[k] != null) return map[k];
  }
  return null;
}

bool? _bool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == 'yes' || s == 'match' || s == 'matches') {
      return true;
    }
    if (s == 'false' || s == 'no' || s == 'mismatch') return false;
  }
  return null;
}

int? _minor(Object? v, String currency) {
  if (v == null) return null;
  if (v is String && v.trim().isEmpty) return null;
  if (v is! num && v is! String) return null;
  if (v is String && double.tryParse(v.trim().replaceAll(',', '.')) == null) {
    return null;
  }
  return minorFromAny(v, currency);
}

String _quote(String name) => '“$name”';

/// Item rows that need a look: low confidence, `review_status: review`, an
/// explicit `needs_review` flag, or named in a `code:Item name` reason.
Set<int> flaggedItemIndexes(
  List<Map<String, dynamic>> items, {
  List<String> reasons = const [],
}) {
  final namedInReasons = <String>{
    for (final r in reasons)
      if (r.contains(':')) r.substring(r.indexOf(':') + 1).trim().toLowerCase(),
  }..remove('');
  final result = <int>{};
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final status = item['review_status']?.toString().trim().toLowerCase();
    if (status == 'confirmed') continue;
    final score = item['confidence_score'];
    final name = item['name']?.toString().trim().toLowerCase() ?? '';
    if (item['needs_review'] == true ||
        status == 'review' ||
        (score is num && score < kReviewConfidenceThreshold) ||
        (name.isNotEmpty && namedInReasons.contains(name))) {
      result.add(i);
    }
  }
  return result;
}

/// Builds the banner, or `null` when there is nothing worth saying.
///
/// * [items]: the receipt's current items (after edits).
/// * [reasons]: `needs_review_reasons` (codes or sentences).
/// * [reconciliation]: read defensively; `printed_total` / `printedTotal`,
///   `computed_total` / `computedTotal`, `matches` / `match`.
/// * [currentTotalMinor]: the live total of the edited bill. When the
///   printed total is known it is compared against this, so the banner
///   turns calm as soon as the user fixes the lines.
/// * [needsReview]: the receipt-level `needs_review` flag.
ReviewBannerContent? buildReviewBanner({
  required List<Map<String, dynamic>> items,
  required String currency,
  required int currentTotalMinor,
  List<String> reasons = const [],
  Map<dynamic, dynamic>? reconciliation,
  bool needsReview = false,
  String? locale,
}) {
  final notes = <ReviewNote>[];
  var warning = false;
  final codes = [for (final r in reasons) r.trim()]
    ..removeWhere((r) => r.isEmpty);
  final lowerCodes = [for (final r in codes) r.toLowerCase()];

  String fmt(int minor) =>
      formatMoneyMinor(minor, currency, showSymbol: false, locale: locale);

  // 1. Totals.
  final rec = reconciliation ?? const {};
  final printed = _minor(
    _pick(rec, const [
      'printed_total',
      'printedTotal',
      'printed',
      'receipt_total',
      'total_printed',
    ]),
    currency,
  );
  final computed = _minor(
    _pick(rec, const [
      'computed_total',
      'computedTotal',
      'calculated_total',
      'calculatedTotal',
      'items_total',
      'sum',
    ]),
    currency,
  );
  final matchesFlag = _bool(_pick(rec, const ['matches', 'match', 'ok']));
  final reasonSaysMismatch = lowerCodes.any(_isTotalMismatch);

  if (printed != null && printed > 0) {
    if (printed == currentTotalMinor) {
      notes.add(
        ReviewNote('bf_scan_review_total_matches', {'amount': fmt(printed)}),
      );
    } else {
      warning = true;
      notes.add(
        ReviewNote('bf_scan_review_total_mismatch', {
          'printed': fmt(printed),
          'computed': fmt(currentTotalMinor),
        }),
      );
    }
  } else if (matchesFlag == false || reasonSaysMismatch) {
    warning = true;
    if (computed != null) {
      notes.add(
        ReviewNote('bf_scan_review_total_mismatch_computed', {
          'computed': fmt(computed),
        }),
      );
    } else {
      notes.add(const ReviewNote('bf_scan_review_total_mismatch_generic'));
    }
  }

  // 2. Lines to check.
  final flagged = flaggedItemIndexes(items, reasons: codes);
  final blurry = lowerCodes.any(_isBlurry);
  if (flagged.isNotEmpty) {
    warning = true;
    final names = [
      for (final i in flagged)
        if ((items[i]['name']?.toString().trim() ?? '').isNotEmpty)
          _quote(items[i]['name'].toString().trim()),
    ];
    final shown = names.take(3).join(', ');
    final extra = names.length - 3;
    final list = extra > 0 ? '$shown +$extra' : shown;
    if (names.isEmpty) {
      notes.add(
        ReviewNote(blurry ? 'bf_scan_review_blurry' : 'bf_scan_review_generic'),
      );
    } else {
      notes.add(
        ReviewNote(
          blurry
              ? 'bf_scan_review_check_items_blurry'
              : 'bf_scan_review_check_items',
          {'items': list},
        ),
      );
    }
  } else if (blurry) {
    warning = true;
    notes.add(const ReviewNote('bf_scan_review_blurry'));
  }

  // 3. Other known reasons, once each.
  final added = <String>{};
  for (var i = 0; i < codes.length; i++) {
    final code = lowerCodes[i];
    if (_isBlurry(code) || _isTotalMismatch(code)) continue;
    String? key;
    for (final (needle, copy) in _reasonCopy) {
      if (code.contains(needle)) {
        key = copy;
        break;
      }
    }
    if (key != null) {
      if (key == 'bf_scan_review_no_total' && printed != null) continue;
      if (added.add(key)) {
        warning = true;
        notes.add(ReviewNote(key));
      }
    } else if (_looksLikeSentence(codes[i]) && added.add(codes[i])) {
      // The backend sent readable text; show it as is.
      warning = true;
      notes.add(ReviewNote(_verbatimKey, {'text': codes[i]}));
    }
  }

  if (notes.isEmpty) {
    if (!needsReview && codes.isEmpty) return null;
    warning = true;
    notes.add(const ReviewNote('bf_scan_review_generic'));
  }

  return ReviewBannerContent(
    tone: warning ? ReviewBannerTone.warning : ReviewBannerTone.calm,
    notes: notes,
    flaggedItemIndexes: flagged,
  );
}

/// Pseudo key for backend sentences shown verbatim (arg `text`).
const String _verbatimKey = '__verbatim__';

/// Translates a [ReviewNote] with [tr]; verbatim backend text passes through.
String translateReviewNote(
  ReviewNote note,
  String Function(String key, Map<String, String> args) tr,
) => note.key == _verbatimKey
    ? note.args['text'] ?? ''
    : tr(note.key, note.args);
