import 'dart:convert';
import 'dart:developer';

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
  static bool panelControlHome = true;
  static const String wifiStateTopic = "config/wifi/state";
  static const numOutputs = 19;
  static const numInputs = 8;
  static const String machineStateTopic = "machine/state/read";

  static const String commandsTopic = "machine/command";
  static const List<String> Commands = [
    "Start",
    "Pause",
    "Resume",
    "Stop",
    "ForceAuthorization",
    "AuthorizeOutputOverride",
    "DisableOutputOverride",
  ];

  static const String outputsReadTopic = "machine/IO/outputs/read";
  static const String inputsReadTopic = "machine/IO/inputs/read";

  final List<bool> outputs = List.filled(numOutputs, false);
  final List<bool> inputs = List.filled(numInputs, false);
  String _stage = "Esperando...";
  bool authorizedSystem = false;

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

  late List<Widget Function()> screens = [_home, _recorder, _configBody];

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
  void subscribeToTopics() {
    mate();

    mqttNotifier.subscribe(machineStateTopic, (payload) {
      final state = jsonDecode(payload) as Map<String, dynamic>;
      final stage = state["stage"];
      if (stage is String) {
        setState(() => _stage = stage);
      }
      final authorized = state["authorizedSystem"];
      if (authorized is bool) {
        authorizedSystem = authorized;
      }
    });

    mqttNotifier.subscribe(outputsReadTopic, (payload) {
      final state = jsonDecode(payload) as Map<String, dynamic>;
      if (state.length != numOutputs) {
        log("Outputs length does not match");
      }

      for (int x = 0; x < numOutputs; x++) {
        final value = state["Q$x"];
        if (value is bool) {
          setState(() => outputs[x] = value);
        } else {
          log("Missing or invalid value for Q$x");
        }
      }
    });

    mqttNotifier.subscribe(inputsReadTopic, (payload) {
      final state = jsonDecode(payload) as Map<String, dynamic>;
      if (state.length != numInputs) {
        log("Inputs length does not match");
      }

      for (int x = 0; x < numInputs; x++) {
        final value = state["I$x"];
        if (value is bool) {
          setState(() => inputs[x] = value);
        } else {
          log("Missing or invalid value for I$x");
        }
      }
    });
  }

  @override
  void unsubscribeToTopics() {
    mqttNotifier.unsubscribe(wifiStateTopic);
    mqttNotifier.unsubscribe(machineStateTopic);
    mqttNotifier.unsubscribe(outputsReadTopic);
    mqttNotifier.unsubscribe(inputsReadTopic);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(super.widget.name),
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
      bottomNavigationBar: NavigationBar(
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

  Widget _home() {
    final width = MediaQuery.sizeOf(context).width;

    if (width > 600) {
      return Row(
        spacing: 15,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _dashboardBody()),
          Expanded(child: _generateIOView()),
        ],
      );
    }
    Widget body = panelControlHome ? _dashboardBody() : _generateIOView();
    return GestureDetector(
      onHorizontalDragEnd: ((details) {
        log("Drag velocity: ${details.primaryVelocity}");
        if (details.primaryVelocity == null) return;

        if (details.primaryVelocity! != 0) setState( () => panelControlHome = !panelControlHome);
      }),
      child: body,
    );
  }

  Widget _dashboardBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(Commands.length, (index) {
        return ElevatedButton(
          onPressed: () {
            mqttNotifier.publish(commandsTopic, Commands[index]);
          },
          child: Text(Commands[index]),
        );
      }),
    );
  }

  Widget _generateIOView() {
    return VisualizeIOPage(
      stage: _stage,
      authorizedSystem: authorizedSystem,
      outputs: outputs,
      inputs: inputs,
    );
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
