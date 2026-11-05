import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/voice/voice_logic.dart';
import 'package:split_bill_app/services/bill_intelligence_service.dart';

void main() {
  final participants = <Map<String, dynamic>>[
    {'id': 'u1', 'name': 'Omar Mahmoud', 'isHost': true},
    {'id': 'g1', 'name': 'Sara Ali'},
    {'id': 'g2', 'name': 'Ali'},
    {'id': 'g3', 'name': '  '},
  ];

  group('resolveHostId', () {
    test('uses the signed-in uid when it is a participant', () {
      expect(resolveHostId('u1', participants), 'u1');
    });
    test('falls back to the isHost participant', () {
      expect(resolveHostId('other', participants), 'u1');
      expect(resolveHostId(null, participants), 'u1');
    });
    test('returns the uid when nobody is host', () {
      expect(
        resolveHostId('x', [
          {'id': 'a', 'name': 'A'},
        ]),
        'x',
      );
    });
  });

  group('buildVoiceAliases', () {
    test('host gets me / I / localized words plus first names', () {
      final a = buildVoiceAliases(
        participants: participants,
        hostId: 'u1',
        languageCode: 'ar',
      );
      expect(a['u1']!.take(2), ['me', 'I']);
      expect(a['u1'], containsAll(['أنا', 'لي', 'Omar']));
      expect(a['g1'], ['Sara']);
      expect(a['g2'], ['Ali']);
      expect(a.containsKey('g3'), isFalse, reason: 'blank names dropped');
    });

    test('dedupes case-insensitively (English "i" vs "I")', () {
      final a = buildVoiceAliases(
        participants: participants,
        hostId: 'u1',
        languageCode: 'en-US',
      );
      final lower = a['u1']!.map((e) => e.toLowerCase()).toList();
      expect(lower.toSet().length, lower.length);
      expect(lower.where((e) => e == 'i').length, 1);
      expect(a['u1'], contains('myself'));
    });

    test('no host id: only first names', () {
      final a = buildVoiceAliases(participants: participants);
      expect(a.keys, ['u1', 'g1', 'g2']);
      expect(a['u1'], ['Omar']);
    });

    test('every supported language has me words', () {
      for (final code
          in 'ar da de en es fr hi id it ja ko nb nl pl pt ru sv '
                  'th tr ur vi zh'
              .split(' ')) {
        expect(kVoiceMeWords[code], isNotEmpty, reason: code);
      }
    });
  });

  group('matchSpeechLocale', () {
    const ids = ['en_US', 'en_GB', 'ar_SA', 'ar_EG', 'fr_CA', 'no_NO', 'zh-CN'];

    test('prefers the system locale of the same language', () {
      expect(matchSpeechLocale('ar', ids, systemLocaleId: 'ar-EG'), 'ar_EG');
      expect(matchSpeechLocale('en', ids, systemLocaleId: 'en_GB'), 'en_GB');
    });
    test('then the usual region', () {
      expect(matchSpeechLocale('ar', ids, systemLocaleId: 'en_US'), 'ar_SA');
      expect(matchSpeechLocale('en', ids), 'en_US');
      expect(matchSpeechLocale('zh', ids), 'zh-CN');
    });
    test('then any locale of the language', () {
      expect(matchSpeechLocale('fr', ids), 'fr_CA');
    });
    test('language aliases (nb -> no, id -> in)', () {
      expect(matchSpeechLocale('nb', ids), 'no_NO');
      expect(matchSpeechLocale('id', ['in_ID']), 'in_ID');
    });
    test('null when the device has none', () {
      expect(matchSpeechLocale('ja', ids), isNull);
      expect(matchSpeechLocale('en', const []), isNull);
    });
  });

  group('splitTranscript', () {
    test('first partial is all tail; a repeat settles all but the end', () {
      final first = splitTranscript('', 'Ali had the burger');
      expect(first.settled, '');
      expect(first.tail, 'Ali had the burger');
      final again = splitTranscript('Ali had the burger', 'Ali had the burger');
      expect(again.settled, 'Ali');
      expect(again.tail, 'had the burger');
    });
    test('words shared with the previous hypothesis settle', () {
      final s = splitTranscript(
        'Ali had the burger split',
        'Ali had the burger split the fries with Sara',
      );
      expect(s.settled, 'Ali had the burger split');
      expect(s.tail, 'the fries with Sara');
    });
    test('revised words stay in the tail', () {
      final s = splitTranscript(
        'Ali had the burglar and',
        'Ali had the burger and the fries',
      );
      expect(s.settled, 'Ali had the');
      expect(s.tail, 'burger and the fries');
    });
    test('final result is fully settled', () {
      final s = splitTranscript('x', '  Ali  had fries ', isFinal: true);
      expect(s, const TranscriptSplit('Ali had fries', ''));
    });
    test('short and empty input', () {
      expect(splitTranscript('', 'hi there').settled, '');
      expect(splitTranscript('', 'hi there').tail, 'hi there');
      expect(splitTranscript('a', '   ').isEmpty, isTrue);
      expect(const TranscriptSplit('a b', 'c').full, 'a b c');
    });
  });

  test('itemMentioned matches name words, plurals, ignores short words', () {
    expect(itemMentioned('Fries, large', 'split the fries with Sara'), isTrue);
    expect(itemMentioned('Beef burger', 'two burgers please'), isTrue);
    expect(itemMentioned('Lemon mints', 'the mint drinks'), isTrue);
    expect(itemMentioned('Tea', 'tea for me'), isTrue);
    expect(itemMentioned('Kunafa', 'Ali had the burger'), isFalse);
    expect(itemMentioned('A B', 'a b'), isFalse);
    expect(itemMentioned('Burger', ''), isFalse);
  });

  test('SoundLevelNormalizer maps into 0..1 and widens its range', () {
    final n = SoundLevelNormalizer();
    expect(n.normalize(-2), 0);
    expect(n.normalize(10), 1);
    expect(n.normalize(4), closeTo(0.5, 1e-9));
    expect(n.normalize(20), 1);
    expect(n.normalize(10), closeTo(12 / 22, 1e-9));
    expect(n.normalize(double.nan), 0);
    final db = SoundLevelNormalizer.dbfs();
    expect(db.normalize(-25), closeTo(0.5, 1e-9));
    expect(db.normalize(-500), 0);
  });

  test('voiceItemsFrom reads names and quantities', () {
    final rows = voiceItemsFrom({
      'items': [
        {'name': 'Burger', 'qty': 1},
        {'name': 'Mint', 'qty': '3'},
        {'name': 'Water', 'qty': 0},
      ],
    });
    expect([for (final r in rows) r.key], ['0', '1', '2']);
    expect([for (final r in rows) r.qty], [1, 3, 1]);
    expect(voiceItemsFrom(const {}), isEmpty);
  });

  group('voicePopValue', () {
    test('plain assignments map when there are no splits', () {
      const r = VoiceAssignResult(
        assignments: {
          '0': ['g2'],
          '1': ['g2', 'g1'],
          '2': [],
        },
      );
      final v = voicePopValue(r);
      expect(v, isA<Map<String, List<String>>>());
      expect(v, {
        '0': ['g2'],
        '1': ['g2', 'g1'],
      });
    });

    test('map with assignments and splits otherwise', () {
      const r = VoiceAssignResult(
        assignments: {
          '0': ['g2'],
        },
        splits: {
          '3': {'u1': 1, 'g1': 2},
        },
      );
      final v = voicePopValue(r) as Map<String, dynamic>;
      expect(v['assignments'], isA<Map<String, List<String>>>());
      expect(v['assignments'], {
        '0': ['g2'],
        '3': ['u1', 'g1'],
      });
      expect(v['splits'], isA<Map<String, Map<String, int>>>());
      expect(v['splits'], {
        '3': {'u1': 1, 'g1': 2},
      });
    });

    test('peopleOnItem merges assignment and split people', () {
      const r = VoiceAssignResult(
        assignments: {
          '1': ['a'],
        },
        splits: {
          '1': {'a': 1, 'b': 1},
        },
      );
      expect(peopleOnItem(r, '1'), ['a', 'b']);
      expect(peopleOnItem(r, '9'), isEmpty);
    });
  });
}
