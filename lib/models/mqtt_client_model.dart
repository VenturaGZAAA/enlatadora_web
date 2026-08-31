import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client_factory.dart';

class MqttModel {
  String brokerIP;
  int brokerPort;
  bool manualDisconnect = true;
  late MqttClient client;
  final String ID = 'M-${kIsWeb ? 'Web' : 'Mobile'}';

  Function(MqttConnectionState)? onConnectionStateChange;

  MqttModel({this.brokerIP = '192.168.10.100', this.brokerPort = 1883}) {
    client = createMqttClient(brokerIP, ID, brokerPort);

    client.setProtocolV311();
    client.connectTimeoutPeriod = 10;
    client.keepAlivePeriod = 20;

    client.autoReconnect = true;
    if (kIsWeb) {
      client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    }
    client.onAutoReconnect = () {
      debugPrint("Reconnecting");
    };

    client.onConnected = () {
      debugPrint("COOOOOONENEEEEEECTEEEED");
      onConnectionStateChange?.call(MqttConnectionState.connected);
    };

    client.onDisconnected = () {
      debugPrint('Weird disconnection');
      onConnectionStateChange?.call(MqttConnectionState.disconnected);
    };

    client.onSubscribed = (topic) {
      debugPrint("Subscribed to $topic");
    };
  }
  void setConnectionMessage(MqttConnectMessage message) {
    client.connectionMessage = message;
  }

  void setIP(String ip) {
    brokerIP = ip;
    client = createMqttClient(brokerIP, ID, brokerPort);
  }

  void setPort(int port) {
    brokerPort = port;
    client = createMqttClient(brokerIP, ID, brokerPort);
  }
}

class MqttSubscriptionData {
  const MqttSubscriptionData({required this.callback, required this.qos});

  final Function(String) callback;
  final MqttQos qos;
}

class MqttState {
  final MqttModel model;
  final MqttConnectionState? connectionState;

  MqttState({required this.model, this.connectionState});

  bool get isConnected => connectionState == MqttConnectionState.connected;

  MqttState copyWith({MqttModel? model, MqttConnectionState? connectionState}) {
    return MqttState(
      model: model ?? this.model,
      connectionState: connectionState ?? this.connectionState,
    );
  }
}
