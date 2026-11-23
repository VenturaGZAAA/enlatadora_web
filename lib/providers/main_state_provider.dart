import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MainPage { control, voice, config }


class MainStateNotifier extends Notifier<MainPage> {
  @override
  MainPage build() {
    return MainPage.control;
  }

  set page(MainPage value){
    state = value;
  }

  void goToConfig() {
    state = MainPage.config;
  }
  void goToControl(){
    state = MainPage.control;
  }

  bool get isControl => state == MainPage.control;
}

final mainPageProvider = NotifierProvider<MainStateNotifier, MainPage>(
  MainStateNotifier.new,
);
