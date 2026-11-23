import 'dart:developer';
import 'dart:html' as html;

import 'package:enlatadora_web/models/app_config.dart';

const String _groqKeyStorageKey = 'groq_api_key';

Future<String?> loadGroqKey() async {
  try {
    if (AppConfig.customGroqKey != null && AppConfig.customGroqKey!.isNotEmpty) {
      return AppConfig.customGroqKey;
    }
    final stored = html.window.localStorage[_groqKeyStorageKey];
    if (stored != null && stored.isNotEmpty) {
      AppConfig.customGroqKey = stored;
      return stored;
    }
  } catch (e) {
    log("Error loading Groq key from localStorage: $e");
  }
  return AppConfig.customGroqKey;
}

Future<void> saveGroqKey(String key) async {
  try {
    AppConfig.customGroqKey = key;
    html.window.localStorage[_groqKeyStorageKey] = key;
  } catch (e) {
    log("Error saving Groq key to localStorage: $e");
  }
}
