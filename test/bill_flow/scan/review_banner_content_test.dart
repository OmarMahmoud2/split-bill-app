import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/scan_receipt/review_banner_content.dart';

/// A fake translator that renders "key{a=b}" so tests see args.
String _tr(String key, Map<String, String> args) {
  if (args.isEmpty) return key;
  final parts = args.entries.map((e) => '${e.key}=${e.value}').join(',');
  return '$key{$parts}';
}

List<Map<String, dynamic>> _items() => [
  {'name': 'Beef burger', 'price': 14.0, 'qty': 1, 'confidence_score': 0.97},
  {'name': 'Lemon mint', 'price': 3.0, 'qty': 3, 'confidence_score': 0.95},
  {'name': 'Kunafa', 'price': 7.0, 'qty': 1, 'confidence_score': 0.55},
];

void main() {
  test('matching printed total and a blurry item (the board example)', () {
    final b = buildReviewBanner(
      items: _items(),
      currency: 'EGP',
      currentTotalMinor: 8127,
      reasons: const ['blurry_item'],
      reconciliation: const {'printed_total': 81.27, 'matches': true},
      locale: 'en',
    )!;
    expect(b.tone, ReviewBannerTone.warning);
    expect(b.flaggedItemIndexes, {2});
    expect(b.notes, const [
      ReviewNote('bf_scan_review_total_matches', {'amount': '81.27'}),
      ReviewNote('bf_scan_review_check_items_blurry', {'items': '“Kunafa”'}),
    ]);
    expect(
      b.text(_tr),
      'bf_scan_review_total_matches{amount=81.27} '
      'bf_scan_review_check_items_blurry{items=“Kunafa”}',
    );
  });

  test('printed total is compared to the live total, not the stale flag', () {
    final b = buildReviewBanner(
      items: [
        {'name': 'Tea', 'price': 5, 'qty': 1},
      ],
      currency: 'USD',
      currentTotalMinor: 500,
      reconciliation: const {'printedTotal': '6.00', 'matches': true},
      locale: 'en',
    )!;
    expect(b.tone, ReviewBannerTone.warning);
    expect(b.notes.single.key, 'bf_scan_review_total_mismatch');
    expect(b.notes.single.args, {'printed': '6.00', 'computed': '5.00'});
  });

  test('all good is calm', () {
    final b = buildReviewBanner(
      items: [
        {'name': 'Tea', 'price': 5, 'qty': 1, 'confidence_score': 0.99},
      ],
      currency: 'USD',
      currentTotalMinor: 500,
      reconciliation: const {'printed_total': 5},
      locale: 'en',
    )!;
    expect(b.tone, ReviewBannerTone.calm);
    expect(b.flaggedItemIndexes, isEmpty);
  });

  test('nothing to say returns null', () {
    expect(
      buildReviewBanner(
        items: [
          {'name': 'Tea', 'price': 5, 'qty': 1},
        ],
        currency: 'USD',
        currentTotalMinor: 500,
      ),
      isNull,
    );
  });

  test('mismatch flag without a printed total', () {
    final b = buildReviewBanner(
      items: const [],
      currency: 'USD',
      currentTotalMinor: 0,
      reconciliation: const {'matches': false, 'computed_total': 12.5},
      locale: 'en',
    )!;
    expect(
      b.notes.single,
      const ReviewNote('bf_scan_review_total_mismatch_computed', {
        'computed': '12.50',
      }),
    );

    final generic = buildReviewBanner(
      items: const [],
      currency: 'USD',
      currentTotalMinor: 0,
      reasons: const ['total_mismatch'],
    )!;
    expect(generic.notes.single.key, 'bf_scan_review_total_mismatch_generic');
  });

  test('known codes map once, sentences pass through, junk is dropped', () {
    final b = buildReviewBanner(
      items: const [],
      currency: 'USD',
      currentTotalMinor: 0,
      reasons: const [
        'handwritten_lines',
        'HANDWRITTEN',
        'currency_guessed',
        'Tip line was hard to read',
        'x_internal_code',
      ],
    )!;
    expect(
      b.text(_tr),
      [
        'bf_scan_review_handwritten',
        'bf_scan_review_currency',
        'Tip line was hard to read',
      ].join(' '),
    );
  });

  test('unknown codes alone fall back to the generic sentence', () {
    final b = buildReviewBanner(
      items: const [],
      currency: 'USD',
      currentTotalMinor: 0,
      reasons: const ['zz_code'],
    )!;
    expect(b.notes.single.key, 'bf_scan_review_generic');
  });

  test('needs_review alone gives the generic sentence', () {
    final b = buildReviewBanner(
      items: const [],
      currency: 'USD',
      currentTotalMinor: 0,
      needsReview: true,
    )!;
    expect(b.tone, ReviewBannerTone.warning);
    expect(b.notes.single.key, 'bf_scan_review_generic');
  });

  test('reconciliation is read defensively', () {
    final b = buildReviewBanner(
      items: const [],
      currency: 'USD',
      currentTotalMinor: 0,
      reconciliation: const {'printed_total': 'n/a', 'matches': 'maybe'},
    );
    expect(b, isNull);
  });

  test('uses currency decimals in amounts', () {
    final b = buildReviewBanner(
      items: const [],
      currency: 'KWD',
      currentTotalMinor: 1500,
      reconciliation: const {'printed_total': 1.5},
      locale: 'en',
    )!;
    expect(b.notes.single.args['amount'], '1.500');
  });

  group('flaggedItemIndexes', () {
    test('low confidence, review status, explicit flag, named reason', () {
      final items = <Map<String, dynamic>>[
        {'name': 'A', 'confidence_score': 0.5},
        {'name': 'B', 'review_status': 'review'},
        {'name': 'C', 'needs_review': true},
        {'name': 'D'},
        {'name': 'E', 'confidence_score': 0.2, 'review_status': 'confirmed'},
      ];
      expect(flaggedItemIndexes(items, reasons: const ['blurry_item:d']), {
        0,
        1,
        2,
        3,
      });
    });

    test('many flagged names are shortened', () {
      final items = [
        for (final n in ['A', 'B', 'C', 'D', 'E'])
          {'name': n, 'confidence_score': 0.1},
      ];
      final b = buildReviewBanner(
        items: items,
        currency: 'USD',
        currentTotalMinor: 0,
      )!;
      expect(b.notes.single.args['items'], '“A”, “B”, “C” +2');
    });
  });
}
