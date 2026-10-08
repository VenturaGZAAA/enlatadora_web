import 'dart:convert';
import 'dart:developer';

import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:flutter/material.dart';

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

  final List<bool> outputs = List.filled(numOutputs, false);
  final List<bool> inputs = List.filled(numInputs, false);
  String _stage = "Esperando...";

  @override
  void subscribeToTopics() {
    mqttNotifier.subscribe("machine/stage", (payload) {
      setState(() => _stage = payload);
    });

    mqttNotifier.subscribe("machine/IO/outputs/read", (payload) {
      final state = jsonDecode(payload) as Map<String, dynamic>;
      if (state.length != numOutputs) {
        log("Outputs length does not match");
      }

      for (int x = 0; x < numOutputs; x++) {
        final value = state["Q$x"];
        if (value is bool) {
          setState(() => outputs[x] = value);
        } else {
          log("Missing or invalid value for Q$x");
        }
      }
    });

    mqttNotifier.subscribe("machine/IO/inputs/read", (payload) {
      final state = jsonDecode(payload) as Map<String, dynamic>;
      if (state.length != numInputs) {
        log("Inputs length does not match");
      }

      for (int x = 0; x < numInputs; x++) {
        final value = state["I$x"];
        if (value is bool) {
          setState(() => inputs[x] = value);
        } else {
          log("Missing or invalid value for I$x");
        }
      }
    });
  }

  @override
  void unsubscribeToTopics() {
    mqttNotifier.unsubscribe("machine/stage");
    mqttNotifier.unsubscribe("machine/IO/outputs/read");
    mqttNotifier.unsubscribe("machine/IO/inputs/read");
  }

  @override
  Widget buildBody(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _outputsView()),
        const SizedBox(height: 15),
        Text(_stage, textAlign: TextAlign.center),
        const Divider(color: Colors.grey),
        const SizedBox(height: 15),
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
            Expanded(
              child: Icon(
                Icons.lightbulb,
                color: outputs[index] ? Colors.yellow : null,
              ),
            ),
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
            Expanded(
              child: IconButton(
                onPressed: () {
                  Map<String, bool> input = {"I$index": !inputs[index]};
                  mqttNotifier.publish(
                    "machine/IO/inputs/write",
                    jsonEncode(input),
                  );
                },
                icon: Icon(
                  Icons.electric_bolt,
                  color: inputs[index] ? Colors.yellow : null,
                ),
              ),
            ),
            Text("$index"),
          ],
        ),
      ),
    );
  }
}
