import 'package:flutter/material.dart';


class WifiConfigPage extends StatelessWidget {
  final TextEditingController _ssidControl;
  final TextEditingController _passControl;

  final void Function() _sendCallback;

  const WifiConfigPage(this._ssidControl,this._passControl,this._sendCallback,{super.key});



  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextField(
          controller: _ssidControl,
          decoration: InputDecoration(
            labelText: "SSID",
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 15),
        TextField(
          controller: _passControl,
          decoration: InputDecoration(
            labelText: "Password",
            border: OutlineInputBorder(),
          ),
        ),
        SizedBox(height: 15),
        ElevatedButton(
          onPressed: _sendCallback,
          child: Text("Send config"),
        ),
      ],
    );
  }

}