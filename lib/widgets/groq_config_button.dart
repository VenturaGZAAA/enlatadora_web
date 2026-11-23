import 'package:material_ui/material_ui.dart';
import 'package:enlatadora_web/models/app_config.dart';
import 'package:enlatadora_web/models/groq_storage/groq_storage.dart';

class GroqConfigButton extends StatefulWidget {
  final VoidCallback? onKeyUpdated;

  const GroqConfigButton({super.key, this.onKeyUpdated});

  @override
  State<GroqConfigButton> createState() => _GroqConfigButtonState();
}

class _GroqConfigButtonState extends State<GroqConfigButton> {
  late final TextEditingController _keyController;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _showConfigDialog(BuildContext context) {
    _keyController.text = AppConfig.customGroqKey ?? "";
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Groq API Key"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _keyController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  hintText: "Enter Groq API Key",
                  labelText: "GROQ_KEY",
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Return"),
            ),
            TextButton(
              onPressed: () async {
                final key = _keyController.text.trim();
                await saveGroqKey(key);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                widget.onKeyUpdated?.call();
              },
              child: const Text("Confirmar"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Configure Groq Key",
      onPressed: () => _showConfigDialog(context),
      icon: Icon(
        Icons.key,
        color: AppConfig.groqKey.length >= 5 ? Colors.lightGreen : null,
      ),
    );
  }
}
