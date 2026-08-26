import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:enlatadora_web/layout/main_layout.dart';
import 'package:enlatadora_web/providers/mqtt_riverpod.dart';

abstract class MqttThingScreen extends ConsumerStatefulWidget {
  final String name;
  final String rootTopico;

  const MqttThingScreen({
    required this.rootTopico,
    this.name = "Thing",
    super.key,
  });

  @override
  MqttThingScreenState createState();
}

abstract class MqttThingScreenState<T extends MqttThingScreen>
    extends ConsumerState<T> {
  late final String rootTopic = widget.rootTopico;
  bool firstSync = false;

  List<Widget> appbarActions = [];

  late final MqttNotifier mqttNotifier;

  void subscribeToTopics();

  void unsubscribeToTopics();

  // void listenerFunction(String topic, String payload);

  Widget buildBody(BuildContext context);

  @override
  @mustCallSuper
  void initState() {
    super.initState();
    mqttNotifier = ref.read(mqttProvider.notifier);
    subscribeToTopics();
  }

  @override
  void dispose() {
    unsubscribeToTopics();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      name: widget.name,
      appbarActions: appbarActions,
      body: buildBody(context),
    );
  }
}
