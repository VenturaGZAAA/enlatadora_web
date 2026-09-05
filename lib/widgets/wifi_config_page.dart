import 'dart:convert';

import 'package:enlatadora_web/providers/mqtt_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enlatadora_web/models/wifi_data.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:enlatadora_web/widgets/helpers.dart';

class WifiConfigPage extends ConsumerStatefulWidget {
  const WifiConfigPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return WifiConfigPageState();
  }
}

class WifiConfigPageState extends ConsumerState<WifiConfigPage> {
  final _ssidController = TextEditingController();
  final _passController = TextEditingController();
  bool _apModeCheck = false;

  late MqttNotifier mqttNotifier;

  @override
  void initState() {
    super.initState();
    mqttNotifier = ref.read(mqttProvider.notifier);
    mate();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> mate() async {
    await mqttNotifier.connect();
  }

  void _publishWiFiData(WiFiData data, String message) {
    const encoder = JsonEncoder.withIndent('  ');
    mqttNotifier.publish(
      "config/wifi/data",
      encoder.convert(data),
      qos: MqttQos.exactlyOnce,
    );

    if (mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }
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
      final bool sendConfirmed = await showConfirmDialog(
        context,
        title: "Set WiFi mode to Access Point",
      );
      if (sendConfirmed) {
        _publishWiFiData(WiFiData(start_ap: true), "Mode set to access point!");
      }
      return;
    }

    // Validate SSID
    if (_ssidController.text.isEmpty) {
      final bool restoreSTA = await showConfirmDialog(context, title: "Do you wan to restore the stored wifi credentials?");
      if (restoreSTA) {
        _publishWiFiData(WiFiData(start_ap: false),"WiFi credentials restored!");
      }
      return;
    }

    // Validate password
    if (_passController.text.isEmpty) {
      final bool proceedWithoutPassword = await showConfirmDialog(
        context,
        title: "Password is empty!",
      );

      if (!proceedWithoutPassword) {
        return;
      }
    }

    final String ssid = _ssidController.text;
    final String pass = _passController.text;

    if (!mounted) {
      debugPrint("Wifi config not mounted");
      return;
    }
    // Optional: Show confirmation before sending
    final bool sendConfirmed = await showConfirmDialog(
      context,
      title: "Send WiFi Configuration?",
      message:
          "SSID: $ssid\nPassword: ${pass.isEmpty ? '(empty)' : pass}\nStart in AP mode: 'No'}",
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

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 15,
      children: [
        TextField(
          controller: _ssidController,
          decoration: InputDecoration(
            labelText: "SSID",
            border: OutlineInputBorder(),
          ),
        ),

        TextField(
          controller: _passController,
          decoration: InputDecoration(
            labelText: "Password",
            border: OutlineInputBorder(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Start in access point mode"),
            Checkbox(
              value: _apModeCheck,
              onChanged: (value) {
                _apModeCheck = value ?? false;
              },
            ),
          ],
        ),
        ElevatedButton(onPressed: _wifiConfirm, child: Text("Send config")),
      ],
    );
  }
}
