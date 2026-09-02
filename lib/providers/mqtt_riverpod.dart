import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'dart:io';

import 'package:enlatadora_web/models/mqtt_client_model.dart';


class MqttNotifier extends AsyncNotifier<MqttState>
    with WidgetsBindingObserver {
  @override
  Future<MqttState> build() async {
    WidgetsBinding.instance.addObserver(this);

    final MqttModel model = MqttModel(brokerIP: "192.168.10.100");

    // Set up the callback to update state when connection changes
    model.onConnectionStateChange = (newState) {
      debugPrint('Connection state changed to: $newState');
      if (state.value != null) {
        // This triggers UI rebuilds
        state = AsyncData(state.value!.copyWith(connectionState: newState));
      }
    };
    debugPrint("Oh genki ya na");
    return MqttState(
      model: model,
      connectionState: MqttConnectionState.disconnected,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle changed to: $state');
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      if (this.state.value?.isConnected == true) {
        debugPrint('App moving to background, disconnecting MQTT...');
        disconnect(manual: false);
      }
      break;
      case AppLifecycleState.inactive:
        if (this.state.value?.isConnected == true) {
          debugPrint('App moving to background, disconnecting MQTT...');
          disconnect(manual: false);
        }
        break;
      case AppLifecycleState.resumed:
        // You could call connect() here if you want auto-reconnect
        if (this.state.value?.model.manualDisconnect == false) {
          connect();
        }
        break;
    }
  }

  void setIPP(String newIP) async {
    if (state.value!.isConnected) {
      state.value!.model.client.disconnect();
      await MqttUtilities.asyncSleep(2);
    }
    state.value?.model.setIP(newIP);
  }

  void setPoort(int newPort) async {
    if (state.value!.isConnected) {
      state.value!.model.client.disconnect();
      await MqttUtilities.asyncSleep(2);
    }
    state.value?.model.setPort(newPort);
  }

  Future<void> connect() async {
    if (state.value == null) return;
    if (state.value!.connectionState == MqttConnectionState.connected) return;

    // Update state to connecting
    state = AsyncData(
      state.value!.copyWith(connectionState: MqttConnectionState.connecting),
    );

    state.value!.model.client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(state.value!.model.ID)
        // .authenticateAs(usrn, pass)
        // .startClean()
        .withWillQos(MqttQos.atMostOnce);

    try {
      await state.value!.model.client.connect();

      // Check connection status after connect attempt
      final isConnected =
          state.value!.model.client.connectionStatus?.state ==
          MqttConnectionState.connected;

      if (isConnected) {
        debugPrint('Connected!');

        for (final topic in subscriptions.keys) {
          // subscribe(topic, subscriptions[topic]!.callback, qos: subscriptions[topic]!.qos);
          state.value!.model.client.subscribe(topic, subscriptions[topic]!.qos);
        }

        _listenTopics();
        state = AsyncData(
          state.value!.copyWith(connectionState: MqttConnectionState.connected),
        );
      } else {
        debugPrint(
          'Connection failed. State: ${state.value!.model.client.connectionStatus?.state}',
        );
        debugPrint(
          'Return code: ${state.value!.model.client.connectionStatus?.returnCode}',
        );
        state = AsyncData(
          state.value!.copyWith(
            connectionState: MqttConnectionState.disconnected,
          ),
        );
      }
    } on NoConnectionException catch (e) {
      debugPrint('EXAMPLE::client exception - $e');
      state.value!.model.client.disconnect();
      state = AsyncData(
        state.value!.copyWith(
          connectionState: MqttConnectionState.disconnected,
        ),
      );
    } on SocketException catch (e) {
      debugPrint('EXAMPLE::socket exception - $e');
      state.value!.model.client.disconnect();
      state = AsyncData(
        state.value!.copyWith(
          connectionState: MqttConnectionState.disconnected,
        ),
      );
    }
  }

  Future<void> disconnect({bool manual = true}) async {
    if (state.value == null) return;
    state.value!.model.manualDisconnect = manual;

    state.value!.model.client.disconnect();
    final isConnected =
        state.value!.model.client.connectionStatus?.state ==
        MqttConnectionState.connected;

    if (!isConnected) {
      debugPrint('Disconnected!');
      state = AsyncData(
        state.value!.copyWith(
          connectionState: MqttConnectionState.disconnected,
        ),
      );
    } else {
      debugPrint("Disconnection failed?");
    }
  }

  String? get ip => state.value?.model.brokerIP;

  bool isConnected() {
    return state.value?.isConnected ?? false;
  }

  void subscribe(
    String topic,
    void Function(String) callback, {
    MqttQos qos = MqttQos.atMostOnce,
  }) {
    state.value?.model.client.subscribe(topic, qos);
    subscriptions.putIfAbsent(
      topic,
      () => MqttSubscriptionData(callback: callback, qos: qos),
    );
  }

  void unsubscribe(String topic) {
    state.value?.model.client.unsubscribe(topic);
    subscriptions.remove(topic);
  }

  Map<String, MqttSubscriptionData> subscriptions = {};

  void _listenTopics() {
    state.value?.model.client.updates!.listen((
      List<MqttReceivedMessage<MqttMessage?>>? c,
    ) {
      final recMess = c![0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );
      String topico = c[0].topic;
      debugPrint('Notification:: topic is <$topico>, payload is <-- $pt -->');
      // listeners(c[0].topic, pt);
      if (subscriptions.containsKey(topico)) {
        subscriptions[topico]?.callback.call(pt);
      }
    });
  }

  void publish(
    String topic,
    String data, {
    MqttQos qos = MqttQos.atMostOnce,
  }) async {
    if (state.value!.isConnected) {
      debugPrint('Publishing: $data');
      final builder = MqttClientPayloadBuilder();
      builder.addString(data);
      state.value?.model.client.publishMessage(topic, qos, builder.payload!);
    } else {
      debugPrint("Attempt...");
      connect();
    }
  }
}

final mqttProvider = AsyncNotifierProvider<MqttNotifier, MqttState>(
  MqttNotifier.new,
);
