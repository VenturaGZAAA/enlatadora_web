import 'dart:convert';

import 'package:enlatadora_web/models/wifi_data.dart';
import 'package:enlatadora_web/providers/mqtt_riverpod.dart';
import 'package:enlatadora_web/providers/recording_provider.dart';
import 'package:enlatadora_web/screens/visualize_io_page.dart';
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:enlatadora_web/screens/voice_recorder_screen.dart';

import 'package:enlatadora_web/widgets/mqtt_config_button.dart';
import 'package:enlatadora_web/widgets/reset_button.dart';
import 'package:enlatadora_web/widgets/wifi_config_page.dart';
import 'package:flutter/material.dart';
import 'package:enlatadora_web/models/mock_data.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:enlatadora_web/providers/home_state_provider.dart';

class HomeScreen extends MqttThingScreen {
  const HomeScreen({super.key, required super.rootTopico})
    : super(name: "home");

  @override
  MqttThingScreenState<MqttThingScreen> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends MqttThingScreenState<HomeScreen> {
  static const String wifiStateTopic = "config/wifi/state";
  bool _wifiUpdated = false;
  WiFiState? _wiFiState;

  static const String voiceTranscriptionsTopic = "voice/keyword/transcription";
  final List<MockData> _transcriptions = [];
  static const int maxTranscriptions = 20;

  static const String voiceMatchTopic = "voice/keyword/match";

  void addTranscription(String transcription) {
    setState(() {
      _transcriptions.add(MockData(DateTime.now(), transcription));
    });

    while (_transcriptions.length > maxTranscriptions) {
      _transcriptions.removeAt(0);
    }
  }

  late List<Widget Function()> screens = [
    _dashboardBody,
    _recorder,
    _configBody,
  ];

  void mate() async {
    await ref.read(mqttProvider.future);
    await mqttNotifier.connect();

    mqttNotifier.subscribe(wifiStateTopic, (content) {
      try {
        setState(() {
          _wiFiState = WiFiState.fromJson(jsonDecode(content));
        });
      } finally {}
    }, qos: MqttQos.atLeastOnce);

    mqttNotifier.subscribe(voiceTranscriptionsTopic, addTranscription);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void subscribeToTopics() {
    mate();
  }

  @override
  void unsubscribeToTopics() {
    mqttNotifier.unsubscribe(wifiStateTopic);
  }

  @override
  void dispose() {
    super.dispose();
    mqttNotifier.disconnect(manual: false);
  }

  @override
  Widget buildBody(BuildContext context) {
    return _layout();
  }

  Widget _layout() {
    if (_wiFiState != null && _wiFiState!.isInvalid() && !_wifiUpdated) {
      setState(() {
        ref.read(homeProvider.notifier).goToConfig();
        _wifiUpdated = true;
      });
    }

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: Text(super.widget.name),
        toolbarHeight: isLandscape ? 44 : kToolbarHeight,
        actions: [
          ...switch (ref.read(homeProvider)) {
            HomePage.control => [],
            HomePage.voice => [
              Icon(
                Icons.record_voice_over,
                color: ref.watch(recordingProvider) ? Colors.lightGreen : null,
              ),
              SizedBox(width: 5),
            ],
            HomePage.config => [MqttConfigButton()],
          },
        ],
      ),
      body: Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(25),
          child: screens[ref.watch(homeProvider).index].call(),
        ),
      ),
      bottomNavigationBar: isLandscape
          ? null
          : NavigationBar(
              selectedIndex: ref.watch(homeProvider).index,
              onDestinationSelected: (index) {
                ref.read(homeProvider.notifier).page = HomePage.values[index];
                if (ref.read(homeProvider) == HomePage.config) {
                  _wiFiState = null;
                }
              },
              destinations: const <Widget>[
                NavigationDestination(
                  icon: Icon(Icons.home),
                  selectedIcon: Icon(Icons.home_outlined),
                  label: "Home",
                ),
                NavigationDestination(
                  icon: Icon(Icons.mic),
                  selectedIcon: Icon(Icons.mic_outlined),
                  label: "Voice",
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  selectedIcon: Icon(Icons.settings_outlined),
                  label: "Settings",
                ),
              ],
            ),
      // floatingActionButton: floatingActionButton,
    );
  }

  Widget _dashboardBody() {
    return VisualizeIOPage();
  }

  Widget _recorder() {
    return VoiceRecorderScreen(
      trans: _transcriptions,
      addTrans: addTranscription,
    );
  }

  Widget _configBody() {
    return ListView(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          spacing: 15,
          children: [WifiConfigPage(), ResetButton()],
        ),
      ],
    );
  }
}
