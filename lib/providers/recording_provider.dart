import 'package:flutter_riverpod/flutter_riverpod.dart';

// class RecorderState {
//   final bool _isRecording;
//   final bool _isProcessing;
//
//   // bool get isRecording => _isRecording;
//   //
//   // bool get isProcessing => _isProcessing;
//
//   RecorderState({bool isRecording = false, bool isProcessing = false})
//     : _isRecording = false,
//       _isProcessing = false;
//
//   RecorderState copyWith({bool? isRecording, bool? isProcessing}) {
//     return RecorderState(
//       isRecording: isRecording ?? _isRecording,
//       isProcessing: isProcessing ?? _isProcessing,
//     );
//   }
// }

class RecordingNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  bool get isRecording => state == true;


  void recordingStart() {
    state = true;
  }

  void recordingStop() {
    state = false;
  }
}

final recordingProvider = NotifierProvider(RecordingNotifier.new);
