import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;

class GroqVoiceRecorder extends StatefulWidget {
  final String groqApiKey;
  final List<String> keywords; // e.g., ['help', 'emergency']
  final void Function(String matchedKeyword)? onKeywordDetected;

  const GroqVoiceRecorder({
    super.key,
    required this.groqApiKey,
    required this.keywords,
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
  Uint8List? _recordedBytes;

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
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav), // WAV is safe
        path: 'temp_recording.wav', // web uses a blob
      );
      setState(() => _isRecording = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording failed: $e')),
      );
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (!_isRecording) return;
    setState(() => _isProcessing = true);

    try {
      // 1. Stop and get the audio data as bytes
      final path = await _recorder.stop();
      setState(() => _isRecording = false);

      Uint8List? bytes;

      if (kIsWeb){
        // On web, path is a blob URL; we need to fetch it
        final response = await http.get(Uri.parse(path!));
        bytes = response.bodyBytes;
      }
      else {
        final file = File(path!);
        log("Path: ${file.path}");
        bytes = await file.readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) {
        throw 'No audio data recorded';
      }
      _recordedBytes = bytes;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<String> _sendToGroq(Uint8List audioBytes) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
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
    return json['text'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isRecording)
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _startRecording,
                icon: const Icon(Icons.mic),
                label: const Text('Start'),
              ),
            if (_isRecording)
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _stopAndTranscribe,
                icon: const Icon(Icons.stop),
                label: const Text('Stop & Transcribe'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_transcription.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transcription:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_transcription),
                  const SizedBox(height: 8),
                  if (_lastKeyword.isNotEmpty)
                    Text(
                      '✅ Keyword detected: $_lastKeyword',
                      style: const TextStyle(color: Colors.green),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}