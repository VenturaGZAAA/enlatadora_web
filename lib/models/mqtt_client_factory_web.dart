import 'dart:html' as html;
import 'package:flutter/cupertino.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

MqttClient createMqttClient(String broker, String clientId, int port) {
   const quadVars = ['WS_PORT'];
  if (dotenv.isEveryDefined(quadVars)){
    final ipp = html.window.location.hostname;
    final ipe = "192.168.10.100";
    broker = "ws://$ipe/mqtt";
    port = dotenv.getInt(quadVars[0]);
  }
  else{
    broker = "ws://$broker";
  }
  return MqttBrowserClient.withPort(broker, clientId, port);
}
