import 'package:flutter/material.dart';

class VoiceKeywordButton extends StatelessWidget {
  const VoiceKeywordButton({
    super.key,
    required this.buttonText,
    required this.buttonIcon,
    required this.onLongPressStart,
    required this.onLongPressCancel,
  });

  final String buttonText;
  final Icon buttonIcon;
  final void Function()? onLongPressStart;
  final void Function()? onLongPressCancel;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => onLongPressStart?.call(),
      onLongPressCancel: () => onLongPressCancel?.call(),
      child: ElevatedButton.icon(
        onPressed: () {}, // gesture detector handles the interaction
        label: Text(buttonText),
        icon: buttonIcon,
      ),
    );
  }
}
