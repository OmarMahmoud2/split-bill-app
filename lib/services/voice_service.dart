import 'dart:io';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:split_bill_app/config/backend_config.dart';

class VoiceService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentPath;

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (await hasPermission()) {
      final dir = await getTemporaryDirectory();
      _currentPath =
          '${dir.path}/voice_command_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Config for standard voice recording
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      );

      // Start recording to file
      await _audioRecorder.start(config, path: _currentPath!);
    } else {
      throw Exception("Microphone permission denied");
    }
  }

  Future<String?> stopRecording() async {
    final path = await _audioRecorder.stop();
    return path;
  }

  Future<String> transcribeAudio(
    String filePath, {
    String language = 'en',
  }) async {
    final File audioFile = File(filePath);
    if (!audioFile.existsSync()) {
      throw Exception("Audio file not found at $filePath");
    }

    final authToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    final request = http.MultipartRequest(
      'POST',
      BackendConfig.voiceTranscriptionUri,
    )..files.add(await http.MultipartFile.fromPath('audio', filePath));

    if (authToken != null && authToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    if (language.isNotEmpty) {
      request.fields['language'] = language;
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final payload = responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final transcript = payload['transcript'] as String?;
      if (transcript == null || transcript.trim().isEmpty) {
        throw Exception('Voice transcription returned no transcript text.');
      }
      return transcript;
    }

    final errorMessage =
        payload['error'] as String? ??
        'Voice transcription failed with status ${response.statusCode}.';
    throw Exception(errorMessage);
  }

  // Clean up
  Future<void> dispose() async {
    _audioRecorder.dispose();
  }
}
