import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:pcmtowave/pcmtowave.dart';
import 'package:pcmtowave/convertToWav.dart';


class GroqVoiceRecorder extends StatefulWidget {
  final String groqApiKey;
  final List<String> keywords;
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

  // Accumulate raw PCM data
  final BytesBuilder _audioBuffer = BytesBuilder();
  StreamSubscription<Uint8List>? _streamSubscription;

  // Recording configuration (adjust as needed)
  static const int sampleRate = 16000;
  static const int numChannels = 1;
  static const int bitsPerSample = 16;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnackBar('Microphone permission denied');
      return;
    }

    try {
      // Clear previous audio data
      _audioBuffer.clear();

      // Start streaming PCM data
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: numChannels,
        ),
      );

      _streamSubscription = stream.listen(
            (Uint8List data) {
          _audioBuffer.add(data);
        },
        onError: (e) => _showSnackBar('Stream error: $e'),
      );

      setState(() => _isRecording = true);
    } catch (e) {
      _showSnackBar('Recording failed: $e');
    }
  }

  Future<void> _stopAndTranscribe() async {
    if (!_isRecording) return;
    setState(() => _isProcessing = true);

    try {
      // Stop recording – this closes the stream
      await _recorder.stop();
      _streamSubscription?.cancel();
      _streamSubscription = null;
      setState(() => _isRecording = false);

      // Get the accumulated PCM data
      final pcmData = _audioBuffer.takeBytes();
      if (pcmData.isEmpty) {
        throw 'No audio data recorded';
      }

      // Build a proper WAV file from PCM
      final wavBytes = _buildWav(
        pcmData,
        sampleRate: sampleRate,
        numChannels: numChannels,
        bitsPerSample: bitsPerSample,
      );

      // Send to Groq
      final transcription = await _sendToGroq(wavBytes);
      setState(() => _transcription = transcription);

      // Check keywords
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
      debugPrint('Error: $e');
      _showSnackBar('Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Builds a complete WAV file from raw PCM data
  Uint8List _buildWav(
      Uint8List pcmData, {
        required int sampleRate,
        required int numChannels,
        required int bitsPerSample,
      }) {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final dataSize = pcmData.length;
    final totalSize = 36 + dataSize;

    final buffer = ByteData(44); // WAV header is 44 bytes
    // RIFF header
    buffer.setUint32(0, 0x52494646, Endian.little); // "RIFF"
    buffer.setUint32(4, totalSize, Endian.little);
    buffer.setUint32(8, 0x57415645, Endian.little); // "WAVE"
    // fmt chunk
    buffer.setUint32(12, 0x666D7420, Endian.little); // "fmt "
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little); // audio format (PCM)
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    // data chunk
    buffer.setUint32(36, 0x64617461, Endian.little); // "data"
    buffer.setUint32(40, dataSize, Endian.little);

    // Combine header + PCM data
    final headerBytes = buffer.buffer.asUint8List();
    final wav = Uint8List(44 + dataSize);
    wav.setAll(0, headerBytes);
    wav.setAll(44, pcmData);
    return wav;
  }

  Future<String> _sendToGroq(Uint8List audioBytes) async {
    debugPrint('Bytes: ${audioBytes.length}');
    if (audioBytes.length < 1000) {
      throw 'Recorded audio is too short or empty.';
    }

    final url = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer ${widget.groqApiKey}'
      ..fields['model'] = 'whisper-large-v3-turbo'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'recording.wav',
          contentType: MediaType('audio', 'wav'),
        ),
      );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw 'Groq API error: $responseBody';
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    return json['text'] ?? '';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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