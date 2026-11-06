import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/manual_entry_screen.dart';
import 'package:split_bill_app/screens/scan_receipt/review_totals.dart';

void main() {
  group('buildReviewDraft', () {
    test('computes the board receipt in minor units', () {
      final draft = buildReviewDraft(
        receiptData: const {},
        currency: 'EGP',
        lines: const [
          (name: 'Beef burger', qty: '1', price: '14.00'),
          (name: 'Fries, large', qty: '1', price: '6.00'),
          (name: 'Grilled fish', qty: '1', price: '18.50'),
          (name: 'Lemon mint', qty: '3', price: '3.00'),
          (name: 'Caesar salad', qty: '1', price: '10.00'),
          (name: 'Kunafa', qty: '1', price: '7.00'),
        ],
        charges: (
          tax: '9.03',
          service: '7.74',
          tip: '',
          delivery: '',
          discount: '',
        ),
      );
      expect(draft.itemsSubtotalMinor, 6450);
      expect(draft.taxMinor, 903);
      expect(draft.serviceMinor, 774);
      expect(draft.grandTotalMinor, 8127);
    });

    test('skips nameless rows, keeps other charges, subtracts discount', () {
      final draft = buildReviewDraft(
        receiptData: const {
          'other_charges': [
            {'label': 'Bag', 'amount': 0.1},
          ],
        },
        currency: 'USD',
        lines: const [
          (name: 'Tea', qty: '2', price: '1.10'),
          (name: '  ', qty: '1', price: '99'),
          (name: 'Cake', qty: 'x', price: 'junk'),
        ],
        charges: (
          tax: '0,20',
          service: '',
          tip: '1',
          delivery: '',
          discount: '0.50',
        ),
      );
      // 2.20 + 0 (junk price, qty 1) + .20 + 1 + .10 - .50
      expect(draft.items.length, 2);
      expect(draft.itemsSubtotalMinor, 220);
      expect(draft.grandTotalMinor, 300);
    });

    test('three-decimal and zero-decimal currencies', () {
      final kwd = buildReviewDraft(
        receiptData: const {},
        currency: 'KWD',
        lines: const [(name: 'A', qty: '1', price: '1.250')],
        charges: (
          tax: '0.125',
          service: '',
          tip: '',
          delivery: '',
          discount: '',
        ),
      );
      expect(kwd.grandTotalMinor, 1375);
      final jpy = buildReviewDraft(
        receiptData: const {},
        currency: 'JPY',
        lines: const [(name: 'A', qty: '2', price: '500')],
        charges: (tax: '100', service: '', tip: '', delivery: '', discount: ''),
      );
      expect(jpy.grandTotalMinor, 1100);
    });
  });

  test('writeReviewTotals writes legacy doubles from minor units', () {
    final data = <String, dynamic>{};
    final draft = buildReviewDraft(
      receiptData: data,
      currency: 'USD',
      lines: const [(name: 'A', qty: '3', price: '0.10')],
      charges: (tax: '0.01', service: '', tip: '', delivery: '', discount: ''),
    );
    writeReviewTotals(data, draft);
    expect(data['subtotal'], 0.3);
    expect(data['tax_amount'], 0.01);
    expect(data['total_amount'], 0.31);
    expect(data['totalMinor'], 31);
    expect(data['currency'], 'USD');
  });

  test('percentLabel', () {
    expect(percentLabel(903, 6450), '14');
    expect(percentLabel(125, 1000), '12.5');
    expect(percentLabel(0, 1000), isNull);
    expect(percentLabel(10, 0), isNull);
  });

  test(
    'taxPercentLabel uses items plus service when that is the whole rate',
    () {
      // Egypt: 14% VAT on 1115.00 + 12% service 133.80.
      expect(taxPercentLabel(17483, 111500, 13380), '14');
      expect(taxPercentLabel(903, 6450, 0), '14');
      expect(taxPercentLabel(125, 1000, 0), '12.5');
      expect(taxPercentLabel(125, 1000, 37), '12.5');
    },
  );

  group('buildManualReceiptData', () {
    test('keeps the legacy shape SplitBillScreen reads', () {
      final data = buildManualReceiptData(
        whatFor: 'Groceries',
        items: const [
          ManualItem(name: 'Milk', unitPriceMinor: 110, qty: 3),
          ManualItem(name: 'Bread', unitPriceMinor: 250),
        ],
        amountMinor: null,
        date: DateTime(2026, 11, 4),
        currencyCode: 'USD',
      );
      expect(data.keys.toSet(), {
        'storeName',
        'total',
        'items',
        'date',
        'taxAmount',
        'serviceChargeAmount',
        'discountAmount',
        'currencyCode',
      });
      expect(data['storeName'], 'Groceries');
      expect(data['total'], 5.8);
      expect(data['items'], [
        {'name': 'Milk', 'price': 1.1, 'qty': 3},
        {'name': 'Bread', 'price': 2.5, 'qty': 1},
      ]);
      expect(data['taxAmount'], 0.0);
      expect(data['currencyCode'], 'USD');
    });

    test('an amount with no items becomes one line', () {
      final data = buildManualReceiptData(
        whatFor: 'Taxi',
        items: const [],
        amountMinor: 12000,
        date: DateTime(2026, 11, 4),
        currencyCode: 'JPY',
      );
      expect(data['total'], 12000.0);
      expect(data['items'], [
        {'name': 'Taxi', 'price': 12000.0, 'qty': 1},
      ]);
    });
  });
}
