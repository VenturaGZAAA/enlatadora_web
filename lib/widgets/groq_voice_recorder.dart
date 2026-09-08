import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;

class GroqVoiceRecorder extends StatefulWidget {
  final String groqApiKey;
  final List<String> keywords; // e.g., ['help', 'emergency']
  final void Function(String matchedKeyword)? onKeywordDetected;
  final void Function(String transcription)? onTranscriptionReceived;

  const GroqVoiceRecorder({
    super.key,
    required this.groqApiKey,
    required this.keywords,
    this.onTranscriptionReceived,
    this.onKeywordDetected,
  });

  @override
  State<GroqVoiceRecorder> createState() => _GroqVoiceRecorderState();
}

class _GroqVoiceRecorderState extends State<GroqVoiceRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  String _transcription = '';
  String _lastKeyword = '';

  @override
  void dispose() {
    _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
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
      setState(() => _isRecording = true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Recording failed: $e')));
    }
  }

  Future<void> _stop() async {
    if (!_isRecording) return;
    log("Stoping");
    _recorder.stop();
    setState(() => _isRecording = false);
  }

  Future<void> _stopAndTranscribe() async {
    if (!_isRecording) return;
    log("Stoping and transcribing");
    setState(() => _isProcessing = true);

    try {
      // 1. Stop and get the audio data as bytes
      final path = await _recorder.stop();
      setState(() => _isRecording = false);

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
      if (bytes == null || bytes.isEmpty) {
        throw 'No audio data recorded';
      }

      // 2. Send to Groq
      final transcription = await _sendToGroq(bytes);
      setState(() => _transcription = transcription);

      // 3. Check for keywords
      for (final keyword in widget.keywords) {
        if (transcription.toLowerCase().contains(keyword.toLowerCase())) {
          _lastKeyword = keyword;
          if (widget.onKeywordDetected != null) {
            widget.onKeywordDetected!(keyword);
          }
          break;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
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
    ButtonStyle? buttonStyle;
    late void Function() buttonFunction;

    if (!_isRecording) {
      buttonText = 'Start';
      buttonIcon = Icon(Icons.mic);
    } else {
      buttonText = 'Stop';
      buttonIcon = Icon(Icons.stop);
      buttonStyle = ElevatedButton.styleFrom(backgroundColor: Colors.red);
    }

    if (!_isProcessing) {
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
