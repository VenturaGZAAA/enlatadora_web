import 'package:flutter_riverpod/flutter_riverpod.dart';

enum HomePage { control, voice, config }


class HomeStateNotifier extends Notifier<HomePage> {
  @override
  HomePage build() {
    return HomePage.control;
  }

  set page(HomePage value){
    state = value;
  }

  void goToConfig() {
    state = HomePage.config;
  }
}

final homeProvider = NotifierProvider<HomeStateNotifier, HomePage>(
  HomeStateNotifier.new,
);
