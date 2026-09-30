import 'package:flutter_riverpod/flutter_riverpod.dart';


class RecordingNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  bool get isRecording => state;


  void recordingStart() {
    state = true;
  }

  void recordingStop() {
    state = false;
  }
}

final recordingProvider = NotifierProvider(RecordingNotifier.new);
