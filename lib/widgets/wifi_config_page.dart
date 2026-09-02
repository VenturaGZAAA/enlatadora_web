import 'package:flutter/material.dart';

class WifiConfigPage extends StatelessWidget {
  final TextEditingController _ssidControl;
  final TextEditingController _passControl;
  final bool _apMode;

  final void Function(bool?) _checkCallback;
  final void Function() _sendCallback;

  const WifiConfigPage({
    required TextEditingController ssidControl,
    required TextEditingController passControl,
    required bool apMode,
    required void Function(bool?) checkCallback,
    required void Function() sendCallback,
    super.key,
  }) : _ssidControl = ssidControl,
       _passControl = passControl,
       _apMode = apMode,
       _checkCallback = checkCallback,
       _sendCallback = sendCallback;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 15,
      children: [
        TextField(
          controller: _ssidControl,
          decoration: InputDecoration(
            labelText: "SSID",
            border: OutlineInputBorder(),
          ),
        ),

        TextField(
          controller: _passControl,
          decoration: InputDecoration(
            labelText: "Password",
            border: OutlineInputBorder(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Start in access point mode"),
            Checkbox(value: _apMode, onChanged: _checkCallback),
          ],
        ),
        ElevatedButton(onPressed: _sendCallback, child: Text("Send config")),
      ],
    );
  }
}
