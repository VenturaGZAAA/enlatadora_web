import 'dart:developer';
import 'dart:html' as html;

const String _groqKeyStorageKey = 'groq_api_key';

String? loadGroqKey() {
  try {
    return html.window.localStorage[_groqKeyStorageKey];
  } catch (e) {
    log("Error loading Groq key from localStorage: $e");
    return null;
  }
}

void saveGroqKey(String key) {
  try {
    html.window.localStorage[_groqKeyStorageKey] = key;
  } catch (e) {
    log("Error saving Groq key to localStorage: $e");
  }
}
