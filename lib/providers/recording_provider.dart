import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecorderState {
  final bool _isRecording;
  final bool _isProcessing;

  // bool get isRecording => _isRecording;
  //
  // bool get isProcessing => _isProcessing;

  RecorderState({bool isRecording = false, bool isProcessing = false})
    : _isRecording = false,
      _isProcessing = false;

  RecorderState copyWith({bool? isRecording, bool? isProcessing}) {
    return RecorderState(
      isRecording: isRecording ?? _isRecording,
      isProcessing: isProcessing ?? _isProcessing,
    );
  }
}

class RecordingNotifier extends Notifier<RecorderState> {
  @override
  RecorderState build() {
    return RecorderState();
  }

  bool get isRecording => state._isRecording;

  bool get isProcessing => state._isProcessing;

  void recordingStart() {
    state = state.copyWith(isRecording: true);
  }

  void recordingStop() {
    state = state.copyWith(isRecording: false);
  }

  void startProcess() {
    state = state.copyWith(isProcessing: true);
  }

  void stopProcess() {
    state = state.copyWith(isProcessing: false);
  }
}

final recordingProvider = NotifierProvider(RecordingNotifier.new);
