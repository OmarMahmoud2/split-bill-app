import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:split_bill_app/config/backend_config.dart';

/// Why recording or server transcription failed. The UI maps each one to a
/// friendly message; the raw cause is only logged.
enum VoiceCaptureFailure {
  permissionDenied,
  offline,
  timeout,
  noSpeech,
  unknown,
}

class VoiceCaptureException implements Exception {
  const VoiceCaptureException(this.failure, {this.statusCode});
  final VoiceCaptureFailure failure;
  final int? statusCode;

  @override
  String toString() => 'VoiceCaptureException($failure, $statusCode)';
}

/// Fallback voice path: records audio with `record` and sends it to the
/// server for transcription. Used only when on-device speech recognition is
/// not available (see `lib/bill_flow/voice/speech_engine.dart`).
class VoiceService {
  VoiceService({AudioRecorder? recorder}) : _recorder = recorder;

  AudioRecorder? _recorder;
  AudioRecorder get _audioRecorder => _recorder ??= AudioRecorder();
  String? _currentPath;

  Future<bool> hasPermission() => _audioRecorder.hasPermission();

  /// Starts recording to a temp file.
  ///
  /// Throws [VoiceCaptureException] with
  /// [VoiceCaptureFailure.permissionDenied] when the microphone is off.
  Future<void> startRecording() async {
    if (!await hasPermission()) {
      throw const VoiceCaptureException(VoiceCaptureFailure.permissionDenied);
    }
    try {
      final dir = await getTemporaryDirectory();
      _currentPath =
          '${dir.path}/voice_command_${DateTime.now().millisecondsSinceEpoch}.m4a';
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );
      await _audioRecorder.start(config, path: _currentPath!);
    } catch (e) {
      debugPrint('VoiceService.startRecording failed: $e');
      throw const VoiceCaptureException(VoiceCaptureFailure.unknown);
    }
  }

  /// Microphone level in dBFS (about -160 silent .. 0 loud) while recording.
  Stream<double> levels({
    Duration interval = const Duration(milliseconds: 120),
  }) => _audioRecorder.onAmplitudeChanged(interval).map((a) => a.current);

  Future<String?> stopRecording() => _audioRecorder.stop();

  /// Stops and throws away the current recording, if any.
  Future<void> cancelRecording() async {
    try {
      await _audioRecorder.cancel();
    } catch (e) {
      debugPrint('VoiceService.cancelRecording failed: $e');
    }
  }

  /// Sends the recording to the server and returns the transcript.
  ///
  /// Throws [VoiceCaptureException] (offline / timeout / noSpeech / unknown).
  /// The temp file is deleted afterwards.
  Future<String> transcribeAudio(
    String filePath, {
    String language = 'en',
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final audioFile = File(filePath);
    if (!audioFile.existsSync()) {
      throw const VoiceCaptureException(VoiceCaptureFailure.noSpeech);
    }
    try {
      final authToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final request = http.MultipartRequest(
        'POST',
        BackendConfig.voiceTranscriptionUri,
      )..files.add(await http.MultipartFile.fromPath('audio', filePath));
      if (authToken != null && authToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      if (language.isNotEmpty) request.fields['language'] = language;

      final response = await request.send().timeout(timeout);
      final responseBody = await response.stream.bytesToString().timeout(
        timeout,
      );
      Map<String, dynamic> payload = const {};
      if (responseBody.isNotEmpty) {
        try {
          final decoded = jsonDecode(responseBody);
          if (decoded is Map<String, dynamic>) payload = decoded;
        } on FormatException {
          payload = const {};
        }
      }
      if (response.statusCode == 200) {
        final transcript = (payload['transcript'] as String?)?.trim() ?? '';
        if (transcript.isEmpty) {
          throw const VoiceCaptureException(VoiceCaptureFailure.noSpeech);
        }
        return transcript;
      }
      debugPrint('voice/transcribe failed: ${response.statusCode}');
      throw VoiceCaptureException(switch (response.statusCode) {
        408 || 502 || 503 || 504 => VoiceCaptureFailure.timeout,
        _ => VoiceCaptureFailure.unknown,
      }, statusCode: response.statusCode);
    } on VoiceCaptureException {
      rethrow;
    } on SocketException {
      throw const VoiceCaptureException(VoiceCaptureFailure.offline);
    } on http.ClientException {
      throw const VoiceCaptureException(VoiceCaptureFailure.offline);
    } on TimeoutException {
      throw const VoiceCaptureException(VoiceCaptureFailure.timeout);
    } catch (e) {
      debugPrint('VoiceService.transcribeAudio failed: $e');
      throw const VoiceCaptureException(VoiceCaptureFailure.unknown);
    } finally {
      try {
        if (audioFile.existsSync()) audioFile.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await _recorder?.dispose();
  }
}
