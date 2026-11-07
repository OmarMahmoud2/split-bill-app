import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:split_bill_app/services/export_service.dart';
import 'package:split_bill_app/services/pdf_font_fallback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('scriptsIn', () {
    test('Latin, Cyrillic and digits need no fallback', () {
      expect(PdfFontFallback.scriptsIn('Dinner 12.50 Обед Bữa tối'), isEmpty);
    });

    test('detects each script the bundled font lacks', () {
      expect(PdfFontFallback.scriptsIn('عشاء'), {PdfScript.arabic});
      expect(PdfFontFallback.scriptsIn('اردو کھانا'), {PdfScript.arabic});
      expect(PdfFontFallback.scriptsIn('रात का खाना'), {PdfScript.devanagari});
      expect(PdfFontFallback.scriptsIn('อาหารเย็น'), {PdfScript.thai});
      expect(PdfFontFallback.scriptsIn('夕食です'), {PdfScript.japanese});
      expect(PdfFontFallback.scriptsIn('저녁 식사'), {PdfScript.korean});
      expect(PdfFontFallback.scriptsIn('晚餐'), {PdfScript.chinese});
    });

    test('mixed text asks for each font once', () {
      expect(PdfFontFallback.scriptsIn('Dinner عشاء 晚餐'), {
        PdfScript.arabic,
        PdfScript.chinese,
      });
    });
  });

  test('fontUrlFromCss reads the first url()', () {
    const css =
        "@font-face { src: url(https://fonts.gstatic.com/l/font?kit=x) format('truetype'); }";
    expect(
      PdfFontFallback.fontUrlFromCss(css),
      'https://fonts.gstatic.com/l/font?kit=x',
    );
  });

  test('offline: no throw, the script is reported missing', () async {
    final client = MockClient(
      (_) async => throw const SocketException('offline'),
    );
    final result = await PdfFontFallback(client: client).load('晚餐');
    expect(result.complete, isFalse);
    expect(result.missing, {PdfScript.chinese});
    expect(result.fonts, isEmpty);
  });

  test('no non-Latin text: nothing is fetched', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('', 500);
    });
    final result = await PdfFontFallback(client: client).load('Dinner 12');
    expect(result.complete, isTrue);
    expect(calls, 0);
  });

  test('online: css then font file are fetched and a font is returned', () async {
    final ttf = File('assets/fonts/Inter/Inter-Regular.ttf').readAsBytesSync();
    final requests = <Uri>[];
    final client = MockClient((req) async {
      requests.add(req.url);
      if (req.url.host == 'fonts.googleapis.com') {
        expect(req.url.queryParameters['family'], 'Noto Sans SC:wght@400');
        expect(req.url.queryParameters['text'], '晚餐');
        return http.Response(
          'src: url(https://fonts.gstatic.com/l/font?kit=a) format("truetype");',
          200,
        );
      }
      return http.Response.bytes(ttf, 200);
    });
    final result = await PdfFontFallback(client: client).load('Dinner 晚餐');
    expect(result.complete, isTrue);
    expect(result.fonts, hasLength(1));
    expect(requests, hasLength(2));
  });

  test('buildPdf accepts fallback fonts', () async {
    final inter = pw.Font.ttf(
      ByteData.sublistView(
        File('assets/fonts/Inter/Inter-Regular.ttf').readAsBytesSync(),
      ),
    );
    final bytes = await ExportService.buildPdf(
      bills: [
        ExportBill(
          id: '1',
          date: DateTime(2026, 11, 1),
          title: 'Dinner',
          currency: 'USD',
          totalMinor: 1000,
          myShareMinor: 500,
          paid: true,
        ),
      ],
      labels: const ExportLabels(
        date: 'D',
        title: 'T',
        group: 'G',
        currency: 'C',
        total: 'Total',
        yourShare: 'S',
        status: 'St',
        paid: 'P',
        unpaid: 'U',
      ),
      formatAmount: (m, c) => '$c $m',
      font: inter,
      fontFallback: [inter],
    );
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
  });
}
