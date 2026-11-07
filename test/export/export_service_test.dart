import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/services/export_service.dart';

const _labels = ExportLabels(
  date: 'Date',
  title: 'Bill',
  group: 'Group',
  currency: 'Currency',
  total: 'Total',
  yourShare: 'Your share',
  status: 'Status',
  paid: 'Paid',
  unpaid: 'Not paid',
);

ExportBill _bill(
  String id,
  DateTime date, {
  String title = 'Dinner',
  String currency = 'USD',
  int total = 1250,
  int share = 625,
  bool paid = false,
  String? group,
}) => ExportBill(
  id: id,
  date: date,
  title: title,
  currency: currency,
  totalMinor: total,
  myShareMinor: share,
  paid: paid,
  groupName: group,
);

void main() {
  group('csvCell', () {
    test('leaves plain values alone', () {
      expect(ExportService.csvCell('Dinner'), 'Dinner');
    });
    test('quotes commas, quotes and newlines (RFC 4180)', () {
      expect(ExportService.csvCell('a,b'), '"a,b"');
      expect(ExportService.csvCell('say "hi"'), '"say ""hi"""');
      expect(ExportService.csvCell('two\nlines'), '"two\nlines"');
    });
    test('neutralises formula injection in text cells only', () {
      expect(ExportService.csvCell('=SUM(A1)'), "'=SUM(A1)");
      expect(ExportService.csvCell('@cmd'), "'@cmd");
      expect(ExportService.csvCell('-12.50', text: false), '-12.50');
    });
  });

  test('plainAmount respects currency decimals and sign', () {
    expect(plainAmount(1250, 'USD'), '12.50');
    expect(plainAmount(5, 'USD'), '0.05');
    expect(plainAmount(1500, 'JPY'), '1500');
    expect(plainAmount(-1500, 'KWD'), '-1.500');
  });

  test(
    'buildCsv has a BOM, a header and one CRLF row per bill, newest first',
    () {
      final csv = ExportService.buildCsv([
        _bill('a', DateTime(2026, 10, 1), title: 'Taxi, airport', paid: true),
        _bill('b', DateTime(2026, 10, 5), title: 'Café', group: 'Dahab trip'),
      ], _labels);
      expect(csv.startsWith(ExportService.bom), isTrue);
      final lines = csv.substring(1).split('\r\n');
      expect(lines.last, isEmpty);
      expect(lines[0], 'Date,Bill,Group,Currency,Total,Your share,Status');
      expect(lines[1], '2026-10-05,Café,Dahab trip,USD,12.50,6.25,Not paid');
      expect(lines[2], '2026-10-01,"Taxi, airport",,USD,12.50,6.25,Paid');
      // Encodes to the UTF-8 BOM bytes Excel looks for.
      expect(utf8.encode(csv).sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    },
  );

  test('inRange is inclusive by day', () {
    final bills = [
      _bill('a', DateTime(2026, 9, 30, 23)),
      _bill('b', DateTime(2026, 10, 1, 8)),
      _bill('c', DateTime(2026, 10, 31, 22)),
      _bill('d', DateTime(2026, 11, 1)),
    ];
    final r = ExportService.inRange(
      bills,
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 31),
    );
    expect(r.map((b) => b.id), ['b', 'c']);
  });

  test('totals are kept per currency', () {
    final t = ExportService.totalsByCurrency([
      _bill('a', DateTime(2026), total: 1000, share: 500),
      _bill('b', DateTime(2026), total: 300, share: 100, currency: 'EGP'),
      _bill('c', DateTime(2026), total: 200, share: 200),
    ]);
    expect(t.map((x) => x.currency), ['EGP', 'USD']);
    expect(t.last.totalMinor, 1200);
    expect(t.last.myShareMinor, 700);
    expect(t.last.count, 2);
  });

  test('fromFirestore reads the bill shape written by the app', () {
    final b = ExportBill.fromFirestore('x', {
      'storeName': 'Sea Breeze Grill',
      'date': Timestamp.fromDate(DateTime(2026, 10, 3)),
      'total': 81.27,
      'currencyCode': 'egp',
      'localImagePath': '/tmp/r.jpg',
      'participants': [
        {'id': 'me', 'share': 30.24, 'isPaid': false, 'status': 'PENDING'},
        {'id': 'ali', 'share': 51.03, 'isPaid': true},
      ],
    }, uid: 'me');
    expect(b.title, 'Sea Breeze Grill');
    expect(b.currency, 'EGP');
    expect(b.totalMinor, 8127);
    expect(b.myShareMinor, 3024);
    expect(b.paid, isFalse);
    expect(b.receiptPath, '/tmp/r.jpg');
    expect(b.date, DateTime(2026, 10, 3));
  });

  test('fromFirestore tolerates missing fields', () {
    final b = ExportBill.fromFirestore(
      'y',
      {},
      uid: 'me',
      fallbackTitle: 'Bill',
    );
    expect(b.title, 'Bill');
    expect(b.totalMinor, 0);
    expect(b.currency, 'USD');
  });

  test('buildPdf produces a PDF document', () async {
    final bytes = await ExportService.buildPdf(
      bills: [
        _bill('a', DateTime(2026, 10, 1)),
        _bill('b', DateTime(2026, 10, 2), currency: 'EGP', paid: true),
      ],
      labels: _labels,
      formatAmount: (m, c) => '$c ${plainAmount(m, c)}',
    );
    expect(bytes.length, greaterThan(500));
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test(
    'buildBillReceiptPdf builds a one-page receipt (RTL names too)',
    () async {
      const receipt = BillReceipt(
        title: 'Sea Breeze Grill',
        dateText: '3 Oct 2026',
        totalText: 'E£812.70',
        paidByText: 'Paid by Omar',
        itemsHeading: 'Items',
        sharesHeading: 'Who owes what',
        methodsHeading: 'Pay to',
        paidLabel: 'Paid',
        notPaidLabel: 'Not yet',
        items: [('Burger', 'E£200.00')],
        people: [
          BillReceiptPerson('Omar', 'E£300.00', true),
          BillReceiptPerson('سارة', 'E£512.70', false),
        ],
        methods: [('InstaPay', 'omar@instapay')],
      );
      final bytes = await ExportService.buildBillReceiptPdf(receipt, rtl: true);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(500));
    },
  );
}
