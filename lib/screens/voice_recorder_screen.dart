
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:flutter/material.dart';

class VoiceRecorderScreen extends MqttThingScreen {
  const VoiceRecorderScreen({super.key}): super(rootTopico: "");

  @override
  MqttThingScreenState<MqttThingScreen> createState() {
    return _VoiceRecorderScreenState();
  }

}

class _VoiceRecorderScreenState extends MqttThingScreenState<VoiceRecorderScreen> {
  @override
  Widget buildBody(BuildContext context) {
    // TODO: implement buildBody
    throw UnimplementedError();
  }

  @override
  void subscribeToTopics() {
    // TODO: implement subscribeToTopics
  }

  @override
  void unsubscribeToTopics() {
    // TODO: implement unsubscribeToTopics
  }

}