import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enlatadora_web/models/mock_data.dart';

class TranscriptionsNotifier extends Notifier<List<MockData>> {
  @override
  List<MockData> build() {
    return [];
  }

  static const _maxTrans = 25;

  void addTranscription(String trans) {
    if (state.length >= _maxTrans) {
      state.removeAt(0);
    }
    state = [...state, MockData.now(trans)];
  }
}

final transcriptionsProvider =
    NotifierProvider<TranscriptionsNotifier, List<MockData>>(
      TranscriptionsNotifier.new,
    );
