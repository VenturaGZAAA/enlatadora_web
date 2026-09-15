import 'package:enlatadora_web/providers/mqtt_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../widgets/helpers.dart';

class ResetButton extends ConsumerWidget {
  const ResetButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(117, 244, 67, 54),
        foregroundColor: Colors.white,
      ).merge(Theme.of(context).elevatedButtonTheme.style),
      onPressed: () async {
        bool reset = await showConfirmDialog(
          context,
          title: "Reset the ESP32?",
        );
        if (reset) {
          ref.read(mqttProvider.notifier).publish("admin/reset/request", "1");
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text("Reset request sent")));
        }
      },
      child: Text("Reset the ESP-32"),
    );
  }
}
