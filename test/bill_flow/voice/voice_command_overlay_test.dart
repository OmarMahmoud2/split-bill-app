import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/voice/speech_engine.dart';
import 'package:split_bill_app/services/bill_intelligence_service.dart';
import 'package:split_bill_app/services/voice_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/voice_command_overlay.dart';

class FakeSpeechEngine implements SpeechEngine {
  FakeSpeechEngine({
    this.initOk = true,
    this.permission = true,
    this.ids = const ['en_US', 'ar_EG'],
  });

  final bool initOk;
  bool permission;
  final List<String> ids;
  void Function(String words, bool isFinal)? onResult;
  void Function(double level)? onSoundLevel;
  void Function(String code, bool permanent)? onError;
  void Function(String status)? onStatus;
  String? listenedLocale;
  int stops = 0;
  int cancels = 0;

  @override
  Future<bool> initialize({
    required void Function(String code, bool permanent) onError,
    required void Function(String status) onStatus,
  }) async {
    this.onError = onError;
    this.onStatus = onStatus;
    return initOk;
  }

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<List<String>> localeIds() async => ids;

  @override
  Future<String?> systemLocaleId() async => 'en_US';

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
    Duration listenFor = const Duration(seconds: 60),
    Duration pauseFor = const Duration(seconds: 4),
  }) async {
    listenedLocale = localeId;
    this.onResult = onResult;
    this.onSoundLevel = onSoundLevel;
  }

  @override
  Future<void> stop() async {
    stops++;
    // The platform delivers the last words as final after a stop.
    final words = _lastWords;
    if (words != null) onResult?.call(words, true);
  }

  String? _lastWords;
  void say(String words, {bool isFinal = false}) {
    _lastWords = words;
    onResult?.call(words, isFinal);
  }

  @override
  Future<void> cancel() async => cancels++;
}

class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.transcript = 'Ali had the burger', this.denied = false});
  final String transcript;
  final bool denied;
  bool started = false;
  final _levels = StreamController<double>.broadcast();

  @override
  Future<void> start() async {
    if (denied) {
      throw const VoiceCaptureException(VoiceCaptureFailure.permissionDenied);
    }
    started = true;
  }

  @override
  Stream<double> levels() => _levels.stream;

  @override
  Future<String> stopAndTranscribe({required String language}) async =>
      transcript;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async => _levels.close();
}

class FakeAssign extends BillIntelligenceService {
  FakeAssign(this.responses);
  final List<Object> responses;
  final calls = <Map<String, Object?>>[];

  @override
  Future<VoiceAssignResult> assignItemsByVoice({
    required List<Map<String, dynamic>> receiptItems,
    required List<Map<String, dynamic>> participants,
    required String transcript,
    String? currentUserId,
    Map<String, List<String>> aliases = const {},
    String transcriptSource = 'on_device',
  }) async {
    calls.add({
      'transcript': transcript,
      'currentUserId': currentUserId,
      'aliases': aliases,
      'transcriptSource': transcriptSource,
      'items': receiptItems.length,
    });
    final next = responses.length > 1 ? responses.removeAt(0) : responses.first;
    if (next is VoiceAssignException) throw next;
    return next as VoiceAssignResult;
  }
}

final receipt = <String, dynamic>{
  'items': [
    {'name': 'Beef burger', 'price': 14.0, 'qty': 1},
    {'name': 'Fries, large', 'price': 6.0, 'qty': 1},
    {'name': 'Kunafa', 'price': 7.0, 'qty': 1},
  ],
};

final people = <Map<String, dynamic>>[
  {'id': 'host', 'name': 'Omar M', 'isHost': true},
  {'id': 'ali', 'name': 'Ali'},
  {'id': 'sara', 'name': 'Sara K'},
];

const okResult = VoiceAssignResult(
  assignments: {
    '0': ['ali'],
    '1': ['ali', 'sara'],
  },
  unassignedItemKeys: ['2'],
  ambiguous: [VoiceAmbiguity(text: 'Not sure who had the kunafa')],
);

Object? popped = 'not popped';
int settingsOpened = 0;

Future<void> pumpSheet(
  WidgetTester tester, {
  required FakeSpeechEngine engine,
  FakeRecorder? recorder,
  FakeAssign? assign,
  bool reduceMotion = true,
}) async {
  popped = 'not popped';
  settingsOpened = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<Object?>(
                  PageRouteBuilder<Object?>(
                    opaque: false,
                    pageBuilder: (_, _, _) => VoiceCommandOverlay(
                      receiptData: receipt,
                      participants: people,
                      speechEngine: engine,
                      recorder: recorder ?? FakeRecorder(),
                      assignService: assign ?? FakeAssign([okResult]),
                      currentUserId: () => 'host',
                      pointsGate: (_) async => true,
                      initialLanguage: 'en',
                      openSettings: () async => settingsOpened++,
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> pickEnglish(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('bf_voice_lang_en')));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Text? transcriptText(WidgetTester tester) {
  final f = find.byKey(const ValueKey('bf_voice_transcript'));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f);
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('permission denied shows the mic-off ErrorState; '
      '"assign by tapping" pops null', (tester) async {
    final engine = FakeSpeechEngine(initOk: false, permission: false);
    await pumpSheet(tester, engine: engine);
    expect(find.text('select_language'), findsOneWidget);

    await pickEnglish(tester);

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('bf_voice_mic_off_title'), findsOneWidget);
    expect(find.text('bf_voice_open_settings'), findsOneWidget);
    expect(find.text('bf_voice_assign_by_tapping'), findsOneWidget);

    await tester.tap(find.text('bf_voice_open_settings'));
    await tester.pump();
    expect(settingsOpened, 1);

    await tester.tap(find.text('bf_voice_assign_by_tapping'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(popped, isNull);
    expect(find.byType(VoiceCommandOverlay), findsNothing);
  });

  testWidgets('fallback recorder denied also shows the mic-off state', (
    tester,
  ) async {
    // Recognition unavailable but permission fine -> record path; the
    // recorder then reports the microphone is off.
    final engine = FakeSpeechEngine(initOk: false, permission: true);
    await pumpSheet(
      tester,
      engine: engine,
      recorder: FakeRecorder(denied: true),
    );
    await pickEnglish(tester);
    expect(find.text('bf_voice_mic_off_title'), findsOneWidget);
  });

  testWidgets('live transcript: settled ink + muted tail, rows, then chips; '
      'Done pops the assignments', (tester) async {
    final engine = FakeSpeechEngine();
    final assign = FakeAssign([okResult]);
    await pumpSheet(tester, engine: engine, assign: assign);
    await pickEnglish(tester);

    expect(engine.listenedLocale, 'en_US');
    expect(
      find.byKey(const ValueKey('bf_voice_transcript_hint')),
      findsOneWidget,
    );
    expect(find.text('bf_voice_privacy_note'), findsOneWidget);
    expect(find.text('Beef burger'), findsOneWidget);
    expect(find.text('Kunafa'), findsOneWidget);

    engine.say('Ali had the burger');
    await tester.pump();
    engine.say('Ali had the burger split the fries with Sara');
    await tester.pump();

    final text = transcriptText(tester)!;
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    final palette = AppPalette.light;
    expect(spans[0].text, '“Ali had the burger');
    expect(spans[1].text, ' split the fries with Sara');
    expect(spans[1].style!.color, palette.textSecondary);
    expect(text.style!.color, palette.textPrimary);
    // Mentioned items show "listening…".
    expect(find.text('bf_voice_listening'), findsNWidgets(2));

    // Done stops recognition; final words go to the assign call.
    await tester.tap(find.byKey(const ValueKey('bf_voice_done')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(engine.stops, 1);
    expect(assign.calls, hasLength(1));
    final call = assign.calls.single;
    expect(call['transcript'], 'Ali had the burger split the fries with Sara');
    expect(call['transcriptSource'], 'on_device');
    expect(call['currentUserId'], 'host');
    final aliases = call['aliases']! as Map<String, List<String>>;
    expect(aliases['host'], containsAll(['me', 'I', 'Omar']));
    expect(aliases['sara'], ['Sara']);

    // Review: chips, amber "not assigned yet", ambiguity note.
    expect(find.text('Ali'), findsNWidgets(2));
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('bf_voice_not_assigned'), findsOneWidget);
    expect(find.text('Not sure who had the kunafa'), findsOneWidget);
    expect(find.text('bf_voice_say_again'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bf_voice_done')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(popped, isA<Map<String, List<String>>>());
    expect(popped, {
      '0': ['ali'],
      '1': ['ali', 'sara'],
    });
  });

  testWidgets('splits pop the assignments + splits map', (tester) async {
    final engine = FakeSpeechEngine();
    final assign = FakeAssign([
      const VoiceAssignResult(
        assignments: {
          '0': ['ali'],
        },
        splits: {
          '1': {'ali': 1, 'sara': 2},
        },
      ),
    ]);
    await pumpSheet(tester, engine: engine, assign: assign);
    await pickEnglish(tester);
    engine.say(
      'Ali had the burger, fries one for Ali two for Sara',
      isFinal: true,
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Sara ×2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bf_voice_done')));
    await tester.pump(const Duration(milliseconds: 400));
    final value = popped! as Map<String, dynamic>;
    expect(value['splits'], {
      '1': {'ali': 1, 'sara': 2},
    });
    expect((value['assignments'] as Map)['1'], ['ali', 'sara']);
  });

  testWidgets('no on-device locale -> records and transcribes on the server', (
    tester,
  ) async {
    final engine = FakeSpeechEngine(ids: const ['ja_JP']);
    final recorder = FakeRecorder(transcript: 'Ali had the burger');
    final assign = FakeAssign([okResult]);
    await pumpSheet(tester, engine: engine, recorder: recorder, assign: assign);
    await pickEnglish(tester);
    expect(recorder.started, isTrue);
    expect(find.text('bf_voice_server_note'), findsOneWidget);
    expect(find.text('bf_voice_recording_hint'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bf_voice_done')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(assign.calls.single['transcriptSource'], 'server');
    expect(find.text('bf_voice_not_assigned'), findsOneWidget);
  });

  testWidgets('assign offline -> friendly ErrorState; Retry re-sends', (
    tester,
  ) async {
    final engine = FakeSpeechEngine();
    final assign = FakeAssign([
      const VoiceAssignException(VoiceAssignFailure.offline),
      okResult,
    ]);
    await pumpSheet(tester, engine: engine, assign: assign);
    await pickEnglish(tester);
    engine.say('Ali had the burger', isFinal: true);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('bf_voice_error_offline'), findsOneWidget);
    expect(find.textContaining('VoiceAssignException'), findsNothing);

    await tester.tap(find.text('feedback_try_again'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(assign.calls, hasLength(2));
    expect(assign.calls[1]['transcript'], 'Ali had the burger');
    expect(find.text('bf_voice_not_assigned'), findsOneWidget);
  });

  testWidgets('speech permission error while listening -> mic-off state', (
    tester,
  ) async {
    final engine = FakeSpeechEngine();
    await pumpSheet(tester, engine: engine);
    await pickEnglish(tester);
    engine.onError!('error_permission', true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('bf_voice_mic_off_title'), findsOneWidget);
  });

  testWidgets('level bars animate with sound when motion is allowed', (
    tester,
  ) async {
    final engine = FakeSpeechEngine();
    await pumpSheet(tester, engine: engine, reduceMotion: false);
    await pickEnglish(tester);
    engine.onSoundLevel!(8);
    await tester.pump(const Duration(milliseconds: 120));
    engine.say('Ali');
    await tester.pump(const Duration(milliseconds: 120));
    expect(transcriptText(tester), isNotNull);
    // Cancel closes the sheet and stops recognition.
    await tester.tap(find.text('cancel'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(engine.cancels, greaterThanOrEqualTo(1));
    expect(popped, isNull);
  });
}
