import 'dart:html' as html;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

MqttClient createMqttClient(String broker, String clientId, int port) {
  final ipp = html.window.location.hostname;
  final ippe = "192.168.10.100";
  broker = "ws://$ipp/mqtt";
  port = 8080;

  return MqttBrowserClient.withPort(broker, clientId, port);
}
