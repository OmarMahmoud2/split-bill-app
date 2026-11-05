/// Pure helpers for the voice assign sheet (no Flutter, no plugins), so they
/// can be unit-tested: aliases, locale matching, transcript display split,
/// sound-level normalising and the value the sheet pops.
library;

import 'package:split_bill_app/services/bill_intelligence_service.dart';

/// Words a speaker uses for themselves, per speech language code. Spoken
/// data for the assign backend, not UI strings. Lower case.
const Map<String, List<String>> kVoiceMeWords = {
  'en': ['me', 'i', 'myself', 'mine', 'my'],
  'ar': ['أنا', 'انا', 'لي', 'ليا', 'عني', 'نفسي'],
  'da': ['jeg', 'mig', 'min'],
  'de': ['ich', 'mich', 'mir', 'mein'],
  'es': ['yo', 'mí', 'mi', 'me'],
  'fr': ['moi', 'je', 'mon', 'ma'],
  'hi': ['मैं', 'मुझे', 'मेरा'],
  'id': ['saya', 'aku'],
  'it': ['io', 'me', 'mi'],
  'ja': ['私', 'わたし', '僕', '俺'],
  'ko': ['나', '저', '내', '제'],
  'nb': ['jeg', 'meg', 'min'],
  'nl': ['ik', 'mij', 'me', 'mijn'],
  'pl': ['ja', 'mnie', 'mi', 'mój'],
  'pt': ['eu', 'mim', 'meu'],
  'ru': ['я', 'мне', 'меня', 'мой'],
  'sv': ['jag', 'mig', 'mej', 'min'],
  'th': ['ฉัน', 'ผม', 'เรา', 'ดิฉัน'],
  'tr': ['ben', 'bana', 'benim'],
  'ur': ['میں', 'مجھے', 'میرا'],
  'vi': ['tôi', 'mình'],
  'zh': ['我'],
};

/// The host participant id: the signed-in uid when it is a participant,
/// else the participant flagged `isHost`, else the uid as given.
String? resolveHostId(
  String? currentUid,
  List<Map<String, dynamic>> participants,
) {
  if (currentUid != null &&
      participants.any((p) => p['id']?.toString() == currentUid)) {
    return currentUid;
  }
  for (final p in participants) {
    if (p['isHost'] == true && p['id'] != null) return p['id'].toString();
  }
  return currentUid;
}

/// First word of a display name ("Sara Ali" -> "Sara"), or '' when blank.
String firstNameOf(Object? name) {
  final text = (name ?? '').toString().trim();
  if (text.isEmpty) return '';
  return text.split(RegExp(r'\s+')).first;
}

/// Aliases sent with the transcript: the host gets "me", "I" and the
/// speech language's own words for "me"; everyone gets their first name.
/// Values are de-duplicated case-insensitively, order kept.
Map<String, List<String>> buildVoiceAliases({
  required List<Map<String, dynamic>> participants,
  String? hostId,
  String languageCode = 'en',
}) {
  final out = <String, List<String>>{};
  void add(String id, String alias) {
    final a = alias.trim();
    if (a.isEmpty) return;
    final list = out.putIfAbsent(id, () => []);
    if (list.any((x) => x.toLowerCase() == a.toLowerCase())) return;
    list.add(a);
  }

  if (hostId != null && hostId.isNotEmpty) {
    add(hostId, 'me');
    add(hostId, 'I');
    for (final w in kVoiceMeWords[_baseLanguage(languageCode)] ?? const []) {
      add(hostId, w);
    }
  }
  for (final p in participants) {
    final id = p['id']?.toString();
    if (id == null || id.isEmpty) continue;
    add(id, firstNameOf(p['name']));
  }
  out.removeWhere((_, v) => v.isEmpty);
  return out;
}

String _baseLanguage(String code) =>
    code.toLowerCase().replaceAll('-', '_').split('_').first;

const Map<String, List<String>> _languageAliases = {
  'nb': ['nb', 'no', 'nn'],
  'id': ['id', 'in'],
  'zh': ['zh', 'cmn'],
};

const Map<String, String> _defaultRegion = {
  'en': 'us',
  'ar': 'sa',
  'da': 'dk',
  'de': 'de',
  'es': 'es',
  'fr': 'fr',
  'hi': 'in',
  'id': 'id',
  'it': 'it',
  'ja': 'jp',
  'ko': 'kr',
  'nb': 'no',
  'nl': 'nl',
  'pl': 'pl',
  'pt': 'br',
  'ru': 'ru',
  'sv': 'se',
  'th': 'th',
  'tr': 'tr',
  'ur': 'pk',
  'vi': 'vn',
  'zh': 'cn',
};

/// Picks the device speech locale id for an app language code.
///
/// Prefers the device's own locale when it speaks that language (so an
/// Egyptian phone gets `ar_EG`), then the language's usual region, then the
/// first locale of that language. Returns the id exactly as the device
/// listed it, or null when the device has none (use the server fallback).
String? matchSpeechLocale(
  String languageCode,
  List<String> availableIds, {
  String? systemLocaleId,
}) {
  final lang = _baseLanguage(languageCode);
  final accepted = _languageAliases[lang] ?? [lang];
  String norm(String id) => id.toLowerCase().replaceAll('-', '_');
  List<String> parts(String id) => norm(id).split('_');

  final candidates = [
    for (final id in availableIds)
      if (accepted.contains(parts(id).first)) id,
  ];
  if (candidates.isEmpty) return null;

  if (systemLocaleId != null) {
    final sys = norm(systemLocaleId);
    for (final c in candidates) {
      if (norm(c) == sys) return c;
    }
  }
  final region = _defaultRegion[lang];
  if (region != null) {
    for (final c in candidates) {
      if (parts(c).last == region && parts(c).length > 1) return c;
    }
  }
  for (final c in candidates) {
    if (parts(c).length == 1) return c;
  }
  return candidates.first;
}

/// A transcript shown as settled ink plus a muted "still being heard" tail.
class TranscriptSplit {
  const TranscriptSplit(this.settled, this.tail);
  final String settled;
  final String tail;

  bool get isEmpty => settled.isEmpty && tail.isEmpty;
  String get full => [settled, tail].where((s) => s.isNotEmpty).join(' ');

  @override
  bool operator ==(Object other) =>
      other is TranscriptSplit &&
      other.settled == settled &&
      other.tail == tail;

  @override
  int get hashCode => Object.hash(settled, tail);

  @override
  String toString() => 'TranscriptSplit("$settled" | "$tail")';
}

/// Splits the recogniser's [current] hypothesis for display.
///
/// Words that also started the [previous] hypothesis have stopped changing,
/// so they are settled; the rest is the tail. While listening the last
/// [minTail] words always stay in the tail, since the recogniser still
/// revises them. A [isFinal] result is fully settled.
TranscriptSplit splitTranscript(
  String previous,
  String current, {
  bool isFinal = false,
  int minTail = 3,
}) {
  final words = _words(current);
  if (words.isEmpty) return const TranscriptSplit('', '');
  if (isFinal) return TranscriptSplit(words.join(' '), '');
  final prev = _words(previous);
  var common = 0;
  while (common < prev.length &&
      common < words.length &&
      prev[common].toLowerCase() == words[common].toLowerCase()) {
    common++;
  }
  final maxSettled = words.length - minTail < 0 ? 0 : words.length - minTail;
  final settledCount = common < maxSettled ? common : maxSettled;
  return TranscriptSplit(
    words.take(settledCount).join(' '),
    words.skip(settledCount).join(' '),
  );
}

List<String> _words(String s) =>
    s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// True when the transcript mentions a word of the item name (3+ letters,
/// case-insensitive), e.g. "fries" for "Fries, large".
bool itemMentioned(String itemName, String transcript) {
  if (transcript.trim().isEmpty) return false;
  final heard = {
    for (final w in transcript.toLowerCase().split(
      RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    ))
      if (w.isNotEmpty) w,
  };
  final nameWords = itemName
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.runes.length >= 3);
  for (final w in nameWords) {
    if (heard.contains(w)) return true;
    // Simple plural: "burgers" mentions "burger" and vice versa.
    if (heard.contains('${w}s') ||
        (w.endsWith('s') && heard.contains(w.substring(0, w.length - 1)))) {
      return true;
    }
  }
  return false;
}

/// Maps raw sound levels to 0..1, widening its range as louder or quieter
/// samples arrive (platforms report different scales: Android rms dB about
/// -2..10, `record` dBFS -160..0).
class SoundLevelNormalizer {
  SoundLevelNormalizer({double min = -2, double max = 10})
    : _min = min,
      _max = max;

  /// For `record` amplitude in dBFS.
  SoundLevelNormalizer.dbfs() : this(min: -50, max: 0);

  double _min;
  double _max;

  double normalize(double raw) {
    if (raw.isNaN || raw.isInfinite) return 0;
    if (raw < _min) _min = raw < -160 ? -160 : raw;
    if (raw > _max) _max = raw;
    final range = _max - _min;
    if (range <= 0) return 0;
    return ((raw - _min) / range).clamp(0.0, 1.0);
  }
}

/// One receipt line in the sheet.
class VoiceItemRow {
  const VoiceItemRow({required this.key, required this.name, this.qty = 1});
  final String key;
  final String name;
  final int qty;
}

List<VoiceItemRow> voiceItemsFrom(Map<String, dynamic> receiptData) {
  final raw = receiptData['items'];
  if (raw is! List) return const [];
  return [
    for (var i = 0; i < raw.length; i++)
      VoiceItemRow(
        key: '$i',
        name: raw[i] is Map ? ((raw[i] as Map)['name'] ?? '').toString() : '',
        qty: raw[i] is Map ? _qty((raw[i] as Map)['qty']) : 1,
      ),
  ];
}

int _qty(Object? v) {
  if (v is num) return v < 1 ? 1 : v.round();
  final parsed = num.tryParse('${v ?? ''}');
  return parsed == null || parsed < 1 ? 1 : parsed.round();
}

/// Participant ids on an item: the shared assignment, plus anyone given
/// units in a per-unit split. Order kept, no duplicates.
List<String> peopleOnItem(VoiceAssignResult result, String itemKey) {
  final ids = <String>[...?result.assignments[itemKey]];
  for (final id in result.splits[itemKey]?.keys ?? const <String>[]) {
    if (!ids.contains(id)) ids.add(id);
  }
  return ids;
}

/// What the sheet pops on Done.
///
/// No per-unit splits: `Map<String, List<String>>` (item index -> ids).
/// Otherwise a map with `'assignments'` (as above) and `'splits'`
/// (`Map<String, Map<String, int>>`, item -> units per id); split-only items also appear in
/// `assignments` with the people that have units, so a reader that ignores
/// `splits` still sees who shares them.
Object voicePopValue(VoiceAssignResult result) {
  final assignments = <String, List<String>>{
    for (final e in result.assignments.entries)
      if (e.value.isNotEmpty) e.key: List<String>.from(e.value),
  };
  if (result.splits.isEmpty) return assignments;
  for (final key in result.splits.keys) {
    final people = peopleOnItem(result, key);
    if (people.isNotEmpty) assignments[key] = people;
  }
  return <String, dynamic>{
    'assignments': assignments,
    'splits': <String, Map<String, int>>{
      for (final e in result.splits.entries)
        e.key: Map<String, int>.from(e.value),
    },
  };
}
