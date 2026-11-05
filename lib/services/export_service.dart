/// Pro export: turns bills into a CSV (Excel / Sheets) or a PDF report.
///
/// The builders are pure (labels are passed in already translated) so they
/// can be unit tested without Firebase or a widget tree.
library;

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:split_bill_app/domain/money.dart' as domain;

/// One bill as it appears in an export, from the signed-in user's view.
class ExportBill {
  const ExportBill({
    required this.id,
    required this.date,
    required this.title,
    required this.currency,
    required this.totalMinor,
    required this.myShareMinor,
    required this.paid,
    this.groupId,
    this.groupName,
    this.receiptPath,
  });

  final String id;
  final DateTime date;
  final String title;
  final String currency;
  final int totalMinor;

  /// The signed-in user's share (0 when they are not a participant).
  final int myShareMinor;

  /// Whether the user's share is settled (or the bill is fully paid).
  final bool paid;
  final String? groupId;
  final String? groupName;

  /// A receipt photo on this device (bills store `localImagePath`).
  final String? receiptPath;

  /// Reads a `bills/{id}` document. Field names follow the bill writers in
  /// `bill_summary_confirm_screen.dart` / `scan_receipt_screen.dart`:
  /// `storeName`, `date` (Timestamp), `total` (double, major units),
  /// `currencyCode` (or legacy `currency_code`), `participants[]` with
  /// `id`, `share`, `isPaid`/`status`, `status`, optional `groupId`,
  /// `groupName` and `localImagePath`.
  factory ExportBill.fromFirestore(
    String id,
    Map<String, dynamic> data, {
    required String uid,
    String fallbackTitle = '',
    String fallbackCurrency = 'USD',
  }) {
    final currency = domain.normalizeCurrency(
      (data['currencyCode'] ?? data['currency_code'] ?? fallbackCurrency)
          .toString(),
    );
    final rawDate = data['date'] ?? data['createdAt'];
    final date = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is DateTime
        ? rawDate
        : DateTime.tryParse(rawDate?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
    final total = (data['total'] as num?)?.toDouble() ?? 0;

    var share = 0.0;
    var paid = data['status']?.toString().toUpperCase() == 'PAID';
    final participants = data['participants'];
    if (participants is List) {
      for (final p in participants) {
        if (p is Map && p['id']?.toString() == uid) {
          share = (p['share'] as num?)?.toDouble() ?? 0;
          paid =
              p['isPaid'] == true ||
              p['status']?.toString().toUpperCase() == 'PAID';
        }
      }
    }
    final title = data['storeName']?.toString().trim() ?? '';
    final receipt = data['localImagePath']?.toString().trim() ?? '';
    return ExportBill(
      id: id,
      date: date,
      title: title.isEmpty ? fallbackTitle : title,
      currency: currency,
      totalMinor: _safeMinor(total, currency),
      myShareMinor: _safeMinor(share, currency),
      paid: paid,
      groupId: data['groupId']?.toString(),
      groupName: data['groupName']?.toString(),
      receiptPath: receipt.isEmpty ? null : receipt,
    );
  }
}

int _safeMinor(double amount, String currency) {
  try {
    return domain.toMinorUnits(amount, currency);
  } catch (_) {
    return 0;
  }
}

/// Plain machine-readable amount ("1234.50", "-3.000"), no grouping or
/// symbol, so spreadsheets parse it as a number.
String plainAmount(int minor, String currency) {
  final decimals = domain.currencyDecimals(currency);
  final negative = minor < 0;
  final digits = minor.abs().toString().padLeft(decimals + 1, '0');
  final whole = digits.substring(0, digits.length - decimals);
  final frac = decimals == 0
      ? ''
      : '.${digits.substring(digits.length - decimals)}';
  return '${negative ? '-' : ''}$whole$frac';
}

/// ISO date (yyyy-MM-dd).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Column headers and status words, already translated.
class ExportLabels {
  const ExportLabels({
    required this.date,
    required this.title,
    required this.group,
    required this.currency,
    required this.total,
    required this.yourShare,
    required this.status,
    required this.paid,
    required this.unpaid,
    this.reportTitle = 'Evens',
    this.totalsHeading = 'Totals',
    this.billsHeading = 'Bills',
    this.receiptsHeading = 'Receipts',
    this.periodLabel = '',
    this.generatedLabel = '',
  });

  final String date;
  final String title;
  final String group;
  final String currency;
  final String total;
  final String yourShare;
  final String status;
  final String paid;
  final String unpaid;
  final String reportTitle;
  final String totalsHeading;
  final String billsHeading;
  final String receiptsHeading;

  /// e.g. "1 Oct 2026 – 31 Oct 2026"; empty hides the line.
  final String periodLabel;

  /// e.g. "Created 5 Nov 2026"; empty hides the line.
  final String generatedLabel;
}

/// Totals per currency (never mixed across currencies).
class CurrencyTotals {
  const CurrencyTotals(
    this.currency,
    this.totalMinor,
    this.myShareMinor,
    this.count,
  );
  final String currency;
  final int totalMinor;
  final int myShareMinor;
  final int count;
}

class ExportService {
  ExportService._();

  /// UTF-8 byte order mark so Excel opens non-Latin text correctly.
  static const String bom = '﻿';

  /// RFC 4180 cell: quotes when needed, doubles quotes. Text cells that a
  /// spreadsheet would run as a formula (=, +, -, @, tab, CR) get a leading
  /// apostrophe ([text] true); numeric cells are left alone.
  static String csvCell(String value, {bool text = true}) {
    var v = value;
    if (text && v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
    final needsQuotes =
        v.contains(',') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r') ||
        v.startsWith(' ') ||
        v.endsWith(' ');
    if (!needsQuotes) return v;
    return '"${v.replaceAll('"', '""')}"';
  }

  /// CSV with a BOM, a header row and one row per bill, CRLF line ends.
  static String buildCsv(List<ExportBill> bills, ExportLabels labels) {
    final rows = <String>[
      [
        labels.date,
        labels.title,
        labels.group,
        labels.currency,
        labels.total,
        labels.yourShare,
        labels.status,
      ].map(csvCell).join(','),
      for (final b in sortBills(bills))
        [
          csvCell(isoDate(b.date), text: false),
          csvCell(b.title),
          csvCell(b.groupName ?? ''),
          csvCell(b.currency, text: false),
          csvCell(plainAmount(b.totalMinor, b.currency), text: false),
          csvCell(plainAmount(b.myShareMinor, b.currency), text: false),
          csvCell(b.paid ? labels.paid : labels.unpaid),
        ].join(','),
    ];
    return '$bom${rows.join('\r\n')}\r\n';
  }

  /// Newest first.
  static List<ExportBill> sortBills(List<ExportBill> bills) =>
      [...bills]..sort((a, b) => b.date.compareTo(a.date));

  /// Bills whose date falls in [start, end] (inclusive by day).
  static List<ExportBill> inRange(
    List<ExportBill> bills,
    DateTime start,
    DateTime end,
  ) {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));
    return bills
        .where((b) => !b.date.isBefore(from) && b.date.isBefore(to))
        .toList();
  }

  static List<CurrencyTotals> totalsByCurrency(List<ExportBill> bills) {
    final map = <String, List<int>>{};
    for (final b in bills) {
      final t = map.putIfAbsent(b.currency, () => [0, 0, 0]);
      t[0] += b.totalMinor;
      t[1] += b.myShareMinor;
      t[2] += 1;
    }
    final keys = map.keys.toList()..sort();
    return [
      for (final k in keys)
        CurrencyTotals(k, map[k]![0], map[k]![1], map[k]![2]),
    ];
  }

  /// A PDF report: title, period, totals per currency, a bill table and,
  /// when [receipts] is given, one page per receipt photo.
  ///
  /// [font]/[boldFont] should be the app's Inter TTFs; Inter covers Latin,
  /// Cyrillic, Greek and Vietnamese. Arabic, Devanagari, Thai and CJK text
  /// has no glyphs in the bundled fonts and renders as boxes.
  /// [formatAmount] formats minor units for display (locale aware).
  static Future<Uint8List> buildPdf({
    required List<ExportBill> bills,
    required ExportLabels labels,
    required String Function(int minor, String currency) formatAmount,
    String Function(DateTime date)? formatDate,
    Map<String, Uint8List> receipts = const {},
    pw.Font? font,
    pw.Font? boldFont,
    bool rtl = false,
  }) async {
    final fmtDate = formatDate ?? isoDate;
    final theme = (font != null)
        ? pw.ThemeData.withFont(base: font, bold: boldFont ?? font)
        : pw.ThemeData.base();
    final doc = pw.Document(title: labels.reportTitle, creator: 'Evens');
    final sorted = sortBills(bills);
    final totals = totalsByCurrency(sorted);
    final direction = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    const ink = PdfColor.fromInt(0xFF111312);
    const muted = PdfColor.fromInt(0xFF5F6360);
    const hairline = PdfColor.fromInt(0xFFE7E6E1);

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        textDirection: direction,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(
            labels.reportTitle,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
          ),
          if (labels.periodLabel.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                labels.periodLabel,
                style: const pw.TextStyle(color: muted),
              ),
            ),
          if (labels.generatedLabel.isNotEmpty)
            pw.Text(
              labels.generatedLabel,
              style: const pw.TextStyle(color: muted, fontSize: 9),
            ),
          pw.SizedBox(height: 16),
          pw.Text(
            labels.totalsHeading,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [labels.currency, labels.total, labels.yourShare, '#'],
            data: [
              for (final t in totals)
                [
                  t.currency,
                  formatAmount(t.totalMinor, t.currency),
                  formatAmount(t.myShareMinor, t.currency),
                  '${t.count}',
                ],
            ],
            border: pw.TableBorder.all(color: hairline, width: 0.5),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF2F1EE),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            labels.billsHeading,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              labels.date,
              labels.title,
              labels.group,
              labels.total,
              labels.yourShare,
              labels.status,
            ],
            data: [
              for (final b in sorted)
                [
                  fmtDate(b.date),
                  b.title,
                  b.groupName ?? '',
                  formatAmount(b.totalMinor, b.currency),
                  formatAmount(b.myShareMinor, b.currency),
                  b.paid ? labels.paid : labels.unpaid,
                ],
            ],
            border: pw.TableBorder.all(color: hairline, width: 0.5),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF2F1EE),
            ),
          ),
        ],
      ),
    );

    for (final b in sorted) {
      final bytes = receipts[b.id];
      if (bytes == null) continue;
      pw.MemoryImage image;
      try {
        image = pw.MemoryImage(bytes);
      } catch (_) {
        continue;
      }
      doc.addPage(
        pw.Page(
          theme: theme,
          textDirection: direction,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${labels.receiptsHeading} · ${b.title} · ${fmtDate(b.date)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return doc.save();
  }
}
