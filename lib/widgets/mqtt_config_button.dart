import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enlatadora_web/providers/mqtt_riverpod.dart';

class MqttConfigButton extends ConsumerStatefulWidget {
  const MqttConfigButton({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _MqttConfigButtonState();
  }
}

class _MqttConfigButtonState extends ConsumerState<MqttConfigButton> {
  final ipController = TextEditingController();
  final portController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    ipController.dispose();
    portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: TextField(
              keyboardType: TextInputType.url,
              controller: ipController,
              decoration: InputDecoration(
                hint: Text(
                  "Server IP",
                ),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: portController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hint: Text(
                      "Server port",
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Regresar"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (ipController.text.isNotEmpty) {
                    ref.read(mqttProvider.notifier).setIPP(ipController.text);
                  }
                  if (portController.text.isNotEmpty) {
                    ref
                        .read(mqttProvider.notifier)
                        .setPoort(ipController.text as int);
                  }

                },
                child: Text("Confirmar"),
              ),
            ],
          ),
        );
      },
      icon: Icon(Icons.wifi),
    );
  }
}