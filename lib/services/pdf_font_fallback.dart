import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;

/// Scripts the bundled Inter font cannot draw. Each maps to a Noto family on
/// Google Fonts, fetched at export time (a subset holding only the characters
/// in the report, so even CJK downloads a few KB, not megabytes).
enum PdfScript {
  arabic('Noto Sans Arabic'),
  devanagari('Noto Sans Devanagari'),
  thai('Noto Sans Thai'),
  japanese('Noto Sans JP'),
  korean('Noto Sans KR'),
  chinese('Noto Sans SC');

  const PdfScript(this.family);
  final String family;
}

/// What [PdfFontFallback.load] produced.
class PdfFontResult {
  const PdfFontResult({this.fonts = const [], this.missing = const {}});

  /// Fallback fonts to hand to the PDF theme.
  final List<pw.Font> fonts;

  /// Scripts present in the text whose font could not be loaded (offline).
  final Set<PdfScript> missing;

  bool get complete => missing.isEmpty;
}

/// Loads Noto fallback fonts for the non-Latin scripts in a report.
class PdfFontFallback {
  PdfFontFallback({http.Client? client, this.timeout = const Duration(seconds: 8)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static final Map<String, Uint8List> _cache = {};

  /// Which of Inter's missing scripts [text] uses. Han characters count as
  /// Japanese when kana appears, Korean with hangul, else Chinese.
  static Set<PdfScript> scriptsIn(String text) {
    var kana = false, hangul = false, han = false;
    final out = <PdfScript>{};
    for (final r in text.runes) {
      if ((r >= 0x0600 && r <= 0x06FF) ||
          (r >= 0x0750 && r <= 0x077F) ||
          (r >= 0x08A0 && r <= 0x08FF) ||
          (r >= 0xFB50 && r <= 0xFDFF) ||
          (r >= 0xFE70 && r <= 0xFEFF)) {
        out.add(PdfScript.arabic);
      } else if (r >= 0x0900 && r <= 0x097F) {
        out.add(PdfScript.devanagari);
      } else if (r >= 0x0E00 && r <= 0x0E7F) {
        out.add(PdfScript.thai);
      } else if ((r >= 0x3040 && r <= 0x30FF) || (r >= 0x31F0 && r <= 0x31FF)) {
        kana = true;
      } else if ((r >= 0xAC00 && r <= 0xD7AF) || (r >= 0x1100 && r <= 0x11FF)) {
        hangul = true;
      } else if ((r >= 0x4E00 && r <= 0x9FFF) ||
          (r >= 0x3400 && r <= 0x4DBF) ||
          (r >= 0x3000 && r <= 0x303F) ||
          (r >= 0xFF00 && r <= 0xFFEF)) {
        han = true;
      }
    }
    if (kana) out.add(PdfScript.japanese);
    if (hangul) out.add(PdfScript.korean);
    if (han && !kana && !hangul) out.add(PdfScript.chinese);
    return out;
  }

  /// The distinct non-ASCII characters of [text], for the font subset
  /// request: the font then holds just what the report needs.
  static String charactersFor(String text) {
    final buf = StringBuffer();
    final seen = <int>{};
    for (final r in text.runes) {
      // ASCII comes from Inter; keep the request URL short.
      if (r < 0x80 || !seen.add(r)) continue;
      buf.writeCharCode(r);
      if (seen.length >= 400) break;
    }
    return buf.toString();
  }

  /// Fetches a font per script found in [text]. Never throws: scripts that
  /// cannot be fetched are reported in [PdfFontResult.missing].
  Future<PdfFontResult> load(String text) async {
    final scripts = scriptsIn(text);
    if (scripts.isEmpty) return const PdfFontResult();
    final fonts = <pw.Font>[];
    final missing = <PdfScript>{};
    for (final script in scripts) {
      try {
        final bytes = await _fetch(script, charactersFor(text));
        fonts.add(pw.Font.ttf(ByteData.sublistView(bytes)));
      } catch (e) {
        if (kDebugMode) debugPrint('PDF font ${script.family}: $e');
        missing.add(script);
      }
    }
    return PdfFontResult(fonts: fonts, missing: missing);
  }

  Future<Uint8List> _fetch(PdfScript script, String chars) async {
    final key = '${script.family}|$chars';
    final cached = _cache[key];
    if (cached != null) return cached;
    final css = Uri.https('fonts.googleapis.com', '/css2', {
      'family': '${script.family}:wght@400',
      'text': chars,
    });
    final cssRes = await _client.get(css).timeout(timeout);
    if (cssRes.statusCode != 200) {
      throw StateError('css ${cssRes.statusCode}');
    }
    final url = fontUrlFromCss(cssRes.body);
    if (url == null) throw StateError('no font url');
    final res = await _client.get(Uri.parse(url)).timeout(timeout);
    if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
      throw StateError('font ${res.statusCode}');
    }
    return _cache[key] = res.bodyBytes;
  }

  /// First `url(...)` in a Google Fonts stylesheet.
  @visibleForTesting
  static String? fontUrlFromCss(String css) =>
      RegExp(r'url\(([^)]+)\)').firstMatch(css)?.group(1)?.replaceAll(RegExp('["\']'), '');
}
