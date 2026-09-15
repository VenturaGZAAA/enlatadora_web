import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:enlatadora_web/providers/recording_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;

class GroqVoiceRecorder extends ConsumerStatefulWidget {
  final String groqApiKey;
  final List<String> keywords; // e.g., ['help', 'emergency']
  final void Function(String? matchedKeyword)? onKeywordDetected;
  final void Function(String transcription)? onTranscriptionReceived;

  const GroqVoiceRecorder({
    super.key,
    required this.groqApiKey,
    required this.keywords,
    this.onTranscriptionReceived,
    this.onKeywordDetected,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _GroqVoiceRecorderState();
  }

}

class _GroqVoiceRecorderState extends ConsumerState<GroqVoiceRecorder> {
  final AudioRecorder _recorder = AudioRecorder();


  @override
  void initState() {
    super.initState();

  }

  @override
  void dispose() {
    _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    log("Startiiiiiiiiiing");
    final recNotifier = ref.read(recordingProvider.notifier);
    if (recNotifier.isProcessing || recNotifier.isRecording) return;
    final hasPermission = await _recorder.hasPermission(request: true);
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    try {
      String? path = 'temp_recording.wav';
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path = "${dir.path}/$path";
      }

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav), // WAV is safe
        path: path, // web uses a blob
      );
      ref.read(recordingProvider.notifier).recordingStart();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Recording failed: $e')));
    }
  }

  Future<void> _stop() async {
    log("Stepin");
    final recNotifier = ref.read(recordingProvider.notifier);
    if (!recNotifier.isRecording || recNotifier.isProcessing) return;
    log("Stoping");
    _recorder.stop();
    ref.read(recordingProvider.notifier).recordingStop();
  }

  Future<void> _stopAndTranscribe() async {
    log("Hard stop");
    final recNotifier = ref.read(recordingProvider.notifier);
    if (!recNotifier.isRecording || recNotifier.isProcessing) return;
    log("Stoping and transcribing");
    ref.read(recordingProvider.notifier).startProcess();

    try {
      // 1. Stop and get the audio data as bytes
      final path = await _recorder.stop();
      ref.read(recordingProvider.notifier).recordingStop();

      Uint8List? bytes;

      if (kIsWeb) {
        // On web, path is a blob URL; we need to fetch it
        final response = await http.get(Uri.parse(path!));
        bytes = response.bodyBytes;
      } else {
        final file = File.fromUri(Uri.parse(path!));
        log("Path: ${file.path}");
        bytes = await file.readAsBytes();
      }
      if (bytes.isEmpty) {
        throw 'No audio data recorded';
      }

      // 2. Send to Groq
      // final transcription = await _sendToGroq(bytes);
      final transcription = "homiees";
      bool detected = false;
      // 3. Check for keywords
      for (final keyword in widget.keywords) {
        if (transcription.toLowerCase().contains(keyword.toLowerCase())) {
          if (widget.onKeywordDetected != null) {
            widget.onKeywordDetected!(keyword);
          }
          detected = true;
          break;
        }
      }
      if (!detected && widget.onKeywordDetected != null) {
        widget.onKeywordDetected!(null);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      ref.read(recordingProvider.notifier).stopProcess();
    }
  }

  Future<String> _sendToGroq(Uint8List audioBytes) async {
    final url = Uri.parse(
      'https://api.groq.com/openai/v1/audio/transcriptions',
    );
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer ${widget.groqApiKey}'
      ..fields['model'] = 'whisper-large-v3-turbo'
      ..fields['language'] = 'en'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'recording.wav',
        ),
      );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw 'Groq API error: $responseBody';
    }

    // Parse JSON
    final json = Map<String, dynamic>.from(
      (responseBody).isNotEmpty ? jsonDecode(responseBody) : {},
    );
    final String transcription = json['text'] ?? '';
    log("Transcription: $transcription");
    if (widget.onTranscriptionReceived != null){
      widget.onTranscriptionReceived?.call(transcription);
    }
    return transcription;
  }


  @override
  Widget build(BuildContext context) {
    late String buttonText;
    late Icon buttonIcon;
    final state = ref.watch(recordingProvider.notifier);

    if (!state.isRecording) {
      buttonText = 'Start';
      buttonIcon = Icon(Icons.mic);
    } else {
      buttonText = 'Stop';
      buttonIcon = Icon(Icons.stop);

    }
    if (!state.isProcessing) {
      return GestureDetector(
        onLongPressStart: (details) => _startRecording(),
        onLongPressCancel: () => _stop(),
        onLongPressEnd: (details) => _stopAndTranscribe(),
        child: ElevatedButton.icon(
          onPressed: () {},
          label: Text(buttonText),
          icon: buttonIcon,
        ),
      );
    } else {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      );
    }
  }
}
