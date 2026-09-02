import 'package:enlatadora_web/models/wifi_data.dart';
import 'package:enlatadora_web/providers/mqtt_riverpod.dart';
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:enlatadora_web/widgets/mqtt_config_button.dart';
import 'package:enlatadora_web/widgets/wifi_config_page.dart';
import 'package:flutter/foundation.dart';
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

  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  bool _apModeCheck = false;

  late List<Widget Function()> screens = [
    _dashboardBody,
    _recorder,
    _configBody,
  ];
  int _currentScreenIndex = 0;

  final List<MockData> reads = List.empty(growable: true);
  static const int MAX_ITEMS = 50;

  @override
  List<Widget> get appbarActions =>
      kIsWeb ? super.appbarActions : [MqttConfigButton()];

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
  }

  @override
  void subscribeToTopics() {
    mate();
  }

  @override
  void unsubscribeToTopics() {
    mqttNotifier.unsubscribe(readTopic);
    mqttNotifier.disconnect(manual: false);
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget buildBody(BuildContext context) {
    return _layout();
  }

  Widget _layout() {
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
    return Center(child: const Text("T.B.D"));
  }

  Future<void> _wifiConfirm() async {
    // Check connection first
    if (!mqttNotifier.isConnected()) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text("Not connected bro")));
      }
      mqttNotifier.connect();
      return;
    }

    if (_apModeCheck) {
      final bool sendConfirmed = await _showConfirmDialog(
        title: "Set WiFi mode to Access Point",
        cancelText: "Cancel",
        confirmText: "Confirm",
      );
      if (sendConfirmed) {
        _publishWiFiData(WiFiData(start_ap: true), "Mode set to access point!");
      }
      return;
    }

    // Validate SSID
    if (_ssidController.text.isEmpty) {
      await _showErrorDialog(
        title: "SSID can not be empty!",
        confirmText: "Go back",
      );
      return;
    }

    // Validate password
    if (_passController.text.isEmpty) {
      final bool proceedWithoutPassword = await _showConfirmDialog(
        title: "Password is empty!",
        cancelText: "Return",
        confirmText: "Confirm",
      );

      if (!proceedWithoutPassword) {
        return;
      }
    }

    final String ssid = _ssidController.text;
    final String pass = _passController.text;

    // Optional: Show confirmation before sending
    final bool sendConfirmed = await _showConfirmDialog(
      title: "Send WiFi Configuration?",
      message:
          "SSID: $ssid\nPassword: ${pass.isEmpty ? '(empty)' : '••••••••'}\nStart in AP mode: 'No'}",
      cancelText: "Cancel",
      confirmText: "Send",
    );

    if (!sendConfirmed) {
      return;
    }
    _publishWiFiData(
      WiFiData(ssid: ssid, pass: pass, start_ap: false),
      "WiFi data sent!",
    );
  }

  void _publishWiFiData(WiFiData data, String message) {
    mqttNotifier.publish(
      "config/wifi/data",
      data.toJson().toString(),
      qos: MqttQos.exactlyOnce,
    );

    if (mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // Helper method for error dialogs (just acknowledgment)
  Future<void> _showErrorDialog({
    required String title,
    String? message,
    required String confirmText,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // Helper method for confirmation dialogs
  Future<bool> _showConfirmDialog({
    required String title,
    String? message,
    required String cancelText,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: message != null ? Text(message) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Widget _configBody() {
    return WifiConfigPage(
      ssidControl: _ssidController,
      passControl: _passController,
      apMode: _apModeCheck,
      checkCallback: (check) => setState(() {
        _apModeCheck = check ?? false;
      }),
      sendCallback: _wifiConfirm,
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
