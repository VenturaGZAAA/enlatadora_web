import 'dart:html' as html;
import 'package:enlatadora_web/models/app_config.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

MqttClient createMqttClient(String broker, String clientId, int port) {
  final address = AppConfig.espBuild?html.window.location.hostname:broker;
  broker = "ws://$address/mqtt";
  port = 8080;

  return MqttBrowserClient.withPort(broker, clientId, port);
}
