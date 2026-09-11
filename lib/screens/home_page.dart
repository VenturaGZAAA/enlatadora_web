import 'dart:convert';
// import 'dart:developer';
// import 'package:enlatadora_web/models/app_config.dart';
import 'package:enlatadora_web/models/wifi_data.dart';
import 'package:enlatadora_web/providers/mqtt_riverpod.dart';
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:enlatadora_web/screens/voice_recorder_screen.dart';

import 'package:enlatadora_web/widgets/helpers.dart';
import 'package:enlatadora_web/widgets/mqtt_config_button.dart';
import 'package:enlatadora_web/widgets/wifi_config_page.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';

class HomePage extends MqttThingScreen {
  const HomePage({super.key, required super.rootTopico}) : super(name: "home");

  @override
  MqttThingScreenState<MqttThingScreen> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends MqttThingScreenState<HomePage> {
  late final String ledTopic = "${widget.rootTopico}led";
  late final String readTopic = "${widget.rootTopico}read";

  WiFiState? _wiFiState;

  late List<Widget Function()> screens = [
    _dashboardBody,
    _recorder,
    _configBody,
  ];

  int _currentScreenIndex = 0;

  final List<MockData> reads = List.empty(growable: true);
  static const int MAX_ITEMS = 50;

  void mate() async {
    await ref.read(mqttProvider.future);
    await mqttNotifier.connect();
    mqttNotifier.subscribe(readTopic, (content) {
      setState(() {
        reads.add(MockData(DateTime.now(), content));
        if (reads.length > MAX_ITEMS) {
          reads.removeAt(0);
        }
      });
    }, qos: MqttQos.atMostOnce);
    mqttNotifier.subscribe("config/wifi/state", (content) {
      try {
        setState(() {
          _wiFiState = WiFiState.fromJson(jsonDecode(content));
        });
      } finally {}
    });
  }

  @override
  void initState() {
    appbarActions.add(MqttConfigButton());
    super.initState();
  }

  @override
  void subscribeToTopics() {
    mate();
  }

  @override
  void unsubscribeToTopics() {
    mqttNotifier.unsubscribe(readTopic);
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
    if (_wiFiState != null && _wiFiState!.isInvalid()) {
      _currentScreenIndex = 2;
    }
    return Scaffold(
      appBar: AppBar(title: Text(super.widget.name), actions: appbarActions),
      body: Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(25),
          child: screens[_currentScreenIndex].call(),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentScreenIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentScreenIndex = index;
          });
          if (_currentScreenIndex == 2) {
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: reads.length,
            itemBuilder: (ctx, index) => reads[index].view(),
          ),
        ),
        SizedBox(height: 15),
        ElevatedButton(
          onPressed: () {
            // debugPrint("It's me dad!");
            if (!mqttNotifier.isConnected()) {
              ScaffoldMessenger.maybeOf(
                context,
              )?.showSnackBar(SnackBar(content: Text("Not connected bro")));
            }
            mqttNotifier.publish(ledTopic, "Hello from the dashboard");
          },
          child: Text("Press me!"),
        ),
      ],
    );
  }


  Widget _recorder() {
    return VoiceRecorderScreen();
  }

  Widget _configBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      spacing: 15,
      children: [WifiConfigPage(), _resetButton()],
    );
  }

  Widget _resetButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(117, 244, 67, 54),
        foregroundColor: Colors.white,
      ).merge(Theme.of(context).elevatedButtonTheme.style),
      onPressed: () async {
        bool reset = await showConfirmDialog(
          context,
          title: "Reset the ESP32?",
        );
        if (reset) {
          mqttNotifier.publish("admin/reset/request", "1");
          if (mounted) {
            ScaffoldMessenger.maybeOf(
              context,
            )?.showSnackBar(SnackBar(content: Text("Reset request sent")));
          }
        }
      },
      child: Text("Reset the ESP-32"),
    );
  }
}

class MockData {
  const MockData(this.time, this.message);

  final DateTime time;
  final String message;

  Widget view() {
    return ListTile(
      title: Text(message),
      subtitle: Text("${time.hour}-${time.minute}-${time.second}"),
    );
  }
}
