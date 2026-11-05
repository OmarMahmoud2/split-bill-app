import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:split_bill_app/services/voice_service.dart';

/// Error codes the speech engine reports (`speech_to_text` names).
abstract final class SpeechErrorCodes {
  static const permission = 'error_permission';
  static const noMatch = 'error_no_match';
  static const speechTimeout = 'error_speech_timeout';
  static const languageNotSupported = 'error_language_not_supported';
  static const network = 'error_network';
  static const networkTimeout = 'error_network_timeout';
}

/// The small slice of on-device speech recognition the voice sheet uses, so
/// widget tests can drive it without a platform channel.
abstract class SpeechEngine {
  /// Prepares recognition (asks for microphone + speech permission the first
  /// time). False when recognition is unavailable or permission was denied.
  Future<bool> initialize({
    required void Function(String code, bool permanent) onError,
    required void Function(String status) onStatus,
  });

  /// Whether permission is granted, without prompting.
  Future<bool> hasPermission();

  Future<List<String>> localeIds();
  Future<String?> systemLocaleId();

  Future<void> listen({
    required String localeId,
    required void Function(String words, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
    Duration listenFor = const Duration(seconds: 60),
    Duration pauseFor = const Duration(seconds: 4),
  });

  Future<void> stop();
  Future<void> cancel();
}

/// [SpeechEngine] backed by `speech_to_text`, on-device only.
class SpeechToTextEngine implements SpeechEngine {
  SpeechToTextEngine([SpeechToText? speech]) : _speech = speech;

  SpeechToText? _speech;
  SpeechToText get _stt => _speech ??= SpeechToText();

  @override
  Future<bool> initialize({
    required void Function(String code, bool permanent) onError,
    required void Function(String status) onStatus,
  }) async {
    try {
      return await _stt.initialize(
        onError: (SpeechRecognitionError e) => onError(e.errorMsg, e.permanent),
        onStatus: onStatus,
      );
    } catch (e) {
      debugPrint('SpeechToTextEngine.initialize failed: $e');
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await _stt.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> localeIds() async {
    try {
      return [for (final l in await _stt.locales()) l.localeId];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<String?> systemLocaleId() async {
    try {
      return (await _stt.systemLocale())?.localeId;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> listen({
    required String localeId,
    required void Function(String words, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
    Duration listenFor = const Duration(seconds: 60),
    Duration pauseFor = const Duration(seconds: 4),
  }) {
    return _stt.listen(
      onResult: (SpeechRecognitionResult r) =>
          onResult(r.recognizedWords, r.finalResult),
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        listenFor: listenFor,
        pauseFor: pauseFor,
        localeId: localeId,
        partialResults: true,
        onDevice: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();
}

/// The server fallback: record audio, then transcribe it on the server.
abstract class VoiceRecorder {
  /// Throws [VoiceCaptureException] (permissionDenied / unknown).
  Future<void> start();

  /// Microphone level in dBFS while recording.
  Stream<double> levels();

  /// Stops and returns the transcript. Throws [VoiceCaptureException].
  Future<String> stopAndTranscribe({required String language});

  Future<void> cancel();
  Future<void> dispose();
}

class ServerVoiceRecorder implements VoiceRecorder {
  ServerVoiceRecorder([VoiceService? service])
    : _service = service ?? VoiceService();
  final VoiceService _service;

  @override
  Future<void> start() => _service.startRecording();

  @override
  Stream<double> levels() => _service.levels();

  @override
  Future<String> stopAndTranscribe({required String language}) async {
    final path = await _service.stopRecording();
    if (path == null) {
      throw const VoiceCaptureException(VoiceCaptureFailure.noSpeech);
    }
    return _service.transcribeAudio(path, language: language);
  }

  @override
  Future<void> cancel() => _service.cancelRecording();

  @override
  Future<void> dispose() => _service.dispose();
}
