import 'package:flutter/material.dart';

class VoiceKeywordButton extends StatelessWidget {
  const VoiceKeywordButton({
    super.key,
    required this.isListening,
    required this.buttonText,
    required this.buttonIcon,
    required this.toStart,
    required this.toStop,
  });

  final String buttonText;
  final Icon buttonIcon;
  final void Function()? toStart;
  final void Function()? toStop;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        if (isListening) {
          toStop?.call();
        } else {
          toStart?.call();
        }
      }, // gesture detector handles the interaction
      label: Text(buttonText),
      icon: buttonIcon,
    );
  }
}
