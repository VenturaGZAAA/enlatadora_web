import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:enlatadora_web/providers/recording_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;

class GroqVoiceRecorder extends ConsumerStatefulWidget {
  final String groqApiKey;
  final List<String> keywords;
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
  ConsumerState<GroqVoiceRecorder> createState() => _GroqVoiceRecorderState();
}

class _GroqVoiceRecorderState extends ConsumerState<GroqVoiceRecorder> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isProcessing = false;
  bool _isListening = false;

  // Streaming state
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  final BytesBuilder _pcmBuffer = BytesBuilder();
  Timer? _chunkTimer;

  // Chunk timing
  static const _chunkInterval = Duration(seconds: 5);
  static const _overlapDuration = Duration(milliseconds: 500);

  // Track last chunk's trailing bytes for overlap
  Uint8List _overlapBytes = Uint8List(0);

  // Deduplication: store last transcribed text for boundary word matching
  String _lastTranscription = '';

  @override
  void dispose() {
    _chunkTimer?.cancel();
    _audioStreamSubscription?.cancel();
    _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Recording lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _startRecording() async {
    if (_isListening || _isProcessing) return;

    final hasPermission = await _recorder.hasPermission(request: true);
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    try {
      // PCM 16-bit is the recommended encoder for streaming because it provides
      // raw audio data that can be split and re-encoded easily.
      final stream = await _recorder.startStream(
        const RecordConfig(encoder: AudioEncoder.pcm16bits),
      );

      _pcmBuffer.clear();
      _overlapBytes = Uint8List(0);
      _lastTranscription = '';

      _audioStreamSubscription = stream.listen(
            (chunk) {
          _pcmBuffer.add(chunk);
        },
        onError: (error) {
          log('Audio stream error: $error');
        },
      );

      // Start the periodic chunk-processing timer
      _chunkTimer = Timer.periodic(_chunkInterval, (_) => _processChunk());

      ref.read(recordingProvider.notifier).recordingStart();
      setState(() => _isListening = true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Recording failed: $e')));
    }
  }

  Future<void> _stop() async {
    if (!_isListening || _isProcessing) return;

    _chunkTimer?.cancel();
    _chunkTimer = null;
    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _recorder.stop();

    ref.read(recordingProvider.notifier).recordingStop();
    setState(() => _isListening = false);
  }

  // ---------------------------------------------------------------------------
  // Chunk processing
  // ---------------------------------------------------------------------------

  /// Called every [_chunkInterval] while recording is active.
  Future<void> _processChunk() async {
    if (_isProcessing) return;

    // Grab whatever PCM data has accumulated since the last chunk.
    final newBytes = _pcmBuffer.takeBytes();
    if (newBytes.isEmpty) return;

    // Build the chunk = overlap (from previous chunk) + new bytes
    final chunk = Uint8List.fromList([..._overlapBytes, ...newBytes]);

    // Save the trailing bytes of this chunk as the overlap for the next one.
    final overlapByteCount = _bytesForDuration(_overlapDuration);
    if (chunk.length > overlapByteCount) {
      _overlapBytes = Uint8List.sublistView(
        chunk,
        chunk.length - overlapByteCount,
      );
    } else {
      _overlapBytes = chunk;
    }

    setState(() => _isProcessing = true);
    try {
      final transcription = await _sendToGroq(chunk, isOverlapChunk: _lastTranscription.isNotEmpty);

      // Deduplicate boundary words against the previous chunk's transcription.
      final deduped = _deduplicate(transcription);

      if (deduped.isNotEmpty) {
        _lastTranscription = deduped;
        widget.onTranscriptionReceived?.call(deduped);

        // Keyword detection
        _checkKeywords(deduped);
      }
    } catch (e) {
      log('Chunk processing error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Removes words at the start of [newText] that already appeared at the end
  /// of [_lastTranscription]. This handles the 500 ms overlap.
  String _deduplicate(String newText) {
    if (_lastTranscription.isEmpty || newText.isEmpty) return newText;

    final lastWords = _lastTranscription.trim().split(RegExp(r'\s+'));
    final newWords = newText.trim().split(RegExp(r'\s+'));

    // Find the longest suffix of lastWords that is a prefix of newWords.
    int matchLength = 0;
    for (int len = 1; len <= lastWords.length && len <= newWords.length; len++) {
      final suffix = lastWords.sublist(lastWords.length - len).join(' ');
      final prefix = newWords.sublist(0, len).join(' ');
      if (suffix.toLowerCase() == prefix.toLowerCase()) {
        matchLength = len;
      }
    }

    if (matchLength == 0) return newText;
    return newWords.sublist(matchLength).join(' ');
  }

  void _checkKeywords(String transcription) {
    final lower = transcription.toLowerCase();
    for (final keyword in widget.keywords) {
      if (lower.contains(keyword.toLowerCase())) {
        widget.onKeywordDetected?.call(keyword);
        return;
      }
    }
    widget.onKeywordDetected?.call(null);
  }

  // ---------------------------------------------------------------------------
  // Groq API
  // ---------------------------------------------------------------------------

  /// Converts a duration to a byte count based on 16 kHz mono PCM 16-bit.
  ///
  /// PCM 16-bit mono at 16 kHz = 32,000 bytes per second.
  int _bytesForDuration(Duration d) {
    const bytesPerSecond = 32000; // 16000 samples/s × 2 bytes/sample
    return (d.inMilliseconds * bytesPerSecond) ~/ 1000;
  }

  /// Wraps raw PCM bytes in a WAV container so Groq accepts the upload.
  Uint8List _wrapPcmInWav(Uint8List pcmData, {int sampleRate = 16000, int channels = 1, int bitsPerSample = 16}) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);
    // "RIFF"
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    // "WAVE"
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    // "fmt "
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little); // subchunk1Size
    header.setUint16(20, 1, Endian.little); // audioFormat = PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // "data"
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final wav = Uint8List(44 + dataSize);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + dataSize, pcmData);
    return wav;
  }

  Future<String> _sendToGroq(Uint8List pcmBytes, {bool isOverlapChunk = false}) async {
    final wavBytes = _wrapPcmInWav(pcmBytes);

    final url = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', url)
      ..headers['Authorization'] = 'Bearer ${widget.groqApiKey}'
      ..fields['model'] = 'whisper-large-v3-turbo'
      ..fields['language'] = 'en'
      ..fields['response_format'] = 'json'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          wavBytes,
          filename: 'chunk.wav',
        ),
      );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw 'Groq API error (${response.statusCode}): $responseBody';
    }

    final json = Map<String, dynamic>.from(
      responseBody.isNotEmpty ? jsonDecode(responseBody) : {},
    );
    final String transcription = json['text'] ?? '';
    log('Chunk transcription: $transcription');
    return transcription;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isRecording = ref.watch(recordingProvider);

    if (_isProcessing && !_isListening) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      );
    }

    final buttonText = isRecording ? 'Press to Stop' : 'Hold to Record';
    final buttonIcon = isRecording ? const Icon(Icons.stop) : const Icon(Icons.mic);

    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressCancel: () => _stop(),
      child: ElevatedButton.icon(
        onPressed: () {}, // gesture detector handles the interaction
        label: Text(buttonText),
        icon: buttonIcon,
      ),
    );
  }
}