import 'dart:convert';
import 'dart:developer';

import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:flutter/material.dart';

class VisualizeIOPage extends MqttThingScreen {
  const VisualizeIOPage({
    required this.stage,
    required this.authorizedSystem,
    required this.outputs,
    required this.inputs,
    super.key,
  }) : super(rootTopico: "");

  final List<bool> outputs;
  final List<bool> inputs;
  final String stage;
  final bool authorizedSystem;

  @override
  MqttThingScreenState<MqttThingScreen> createState() {
    return _CanTestPageState();
  }
}

class _CanTestPageState extends MqttThingScreenState<VisualizeIOPage> {
  static const _maxItemWith = 100.0;

  @override
  void subscribeToTopics() {}

  @override
  void unsubscribeToTopics() {}

  @override
  Widget buildBody(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _outputsView()),
        const SizedBox(height: 5),
        const Divider(color: Colors.grey),
        const SizedBox(height: 5),
        Expanded(flex: 1, child: _inputsView()),
        const Divider(color: Colors.grey),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Text(widget.stage, textAlign: TextAlign.center),
            Checkbox(value: widget.authorizedSystem, onChanged: (_) {}),
          ],
        ),
      ],
    );
  }

  Widget _outputsView() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxItemWith,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        childAspectRatio: 1,
      ),
      itemCount: widget.outputs.length,
      itemBuilder: (context, index) => Card.outlined(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                Map<String, bool> input = {"Q$index": !widget.outputs[index]};
                mqttNotifier.publish(
                  "machine/IO/outputs/write",
                  jsonEncode(input),
                );
              },
              icon: Icon(
                Icons.lightbulb,
                color: widget.outputs[index] ? Colors.yellow : null,
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
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _maxItemWith,
        crossAxisSpacing: 5,
        mainAxisSpacing: 5,
        childAspectRatio: 1,
      ),
      itemCount: widget.inputs.length,
      itemBuilder: (context, index) => Card.outlined(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.electric_bolt,
                color: widget.inputs[index] ? Colors.yellow : null,
              ),
            ),
            Text("$index"),
          ],
        ),
      ),
    );
  }
}
