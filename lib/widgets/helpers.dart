
import 'package:flutter/material.dart';

// Helper method for confirmation dialogs
Future<bool> showConfirmDialog(BuildContext context,{
  required String title,
  String? message,
  String confirmText = "Confirm",
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message != null ? Text(message) : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );

  return result ?? false;
}


// Helper method for error dialogs (just acknowledgment)
Future<void> showErrorDialog(BuildContext context,{
  required String title,
  String? message,
  required String confirmText,
}) async {
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message != null ? Text(message) : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(confirmText),
        ),
      ],
    ),
  );
}
