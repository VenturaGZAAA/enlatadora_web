import 'dart:developer';

String? _inMemoryGroqKey;

String? loadGroqKey() {
  try {
    return _inMemoryGroqKey;
  } catch (e) {
    log("Error loading Groq key from stub storage: $e");
    return null;
  }
}

void saveGroqKey(String key) {
  try {
    _inMemoryGroqKey = key;
  } catch (e) {
    log("Error saving Groq key to stub storage: $e");
  }
}
