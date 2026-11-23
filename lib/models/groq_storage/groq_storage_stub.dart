import 'dart:developer';
import 'dart:io';

import 'package:enlatadora_web/models/app_config.dart';
import 'package:path_provider/path_provider.dart';

const String _groqFileName = 'groq_api_key.txt';

Future<File> _getGroqFile() async {
  final directory = await getApplicationDocumentsDirectory();
  return File('${directory.path}/$_groqFileName');
}

Future<String?> loadGroqKey() async {
  try {
    if (AppConfig.customGroqKey != null && AppConfig.customGroqKey!.isNotEmpty) {
      return AppConfig.customGroqKey;
    }
    final file = await _getGroqFile();
    if (await file.exists()) {
      final key = await file.readAsString();
      final trimmed = key.trim();
      if (trimmed.isNotEmpty) {
        AppConfig.customGroqKey = trimmed;
        return trimmed;
      }
    }
  } catch (e) {
    log("Error loading Groq key from persistent file: $e");
  }
  return AppConfig.customGroqKey;
}

Future<void> saveGroqKey(String key) async {
  try {
    AppConfig.customGroqKey = key;
    final file = await _getGroqFile();
    await file.writeAsString(key.trim());
  } catch (e) {
    log("Error saving Groq key to persistent file: $e");
  }
}
