import 'dart:convert';

import 'package:enlatadora_web/models/wifi_data.dart';
import 'package:enlatadora_web/providers/mqtt_riverpod.dart';
import 'package:enlatadora_web/providers/recording_provider.dart';
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';

class CanTestPage extends MqttThingScreen {
  const CanTestPage({super.key}) : super(rootTopico: "");

  @override
  MqttThingScreenState<MqttThingScreen> createState() {
    return _CanTestPageState();
  }
}

class _CanTestPageState extends MqttThingScreenState<CanTestPage> {
  static const numOutputs = 19;
  static const numInputs = 8;

  @override
  void subscribeToTopics() {
    // TODO: implement subscribeToTopics
  }

  @override
  void unsubscribeToTopics() {
    // TODO: implement unsubscribeToTopics
  }

  @override
  Widget buildBody(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _outputsView()),
        const SizedBox(height: 20),
        const Text("Etapa: 0", textAlign: TextAlign.center),
        const Divider(color: Colors.grey),
        const SizedBox(height: 20),
        Expanded(flex: 1, child: _inputsView()),
      ],
    );
  }

  Widget _outputsView() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
      ),
      itemCount: numOutputs,
      itemBuilder: (context, index) => Card.outlined(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Icon(Icons.lightbulb)),
            Text("$index"),
          ],
        ),
      ),
    );
  }

  Widget _inputsView() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: numInputs,
      itemBuilder: (context, index) => Card.outlined(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Icon(Icons.electric_bolt)),
            Text("$index"),
          ],
        ),
      ),
    );
  }
}
