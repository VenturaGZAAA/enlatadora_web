class AppConfig {
  static const bool espBuild = bool.fromEnvironment("ESP_BUILD",defaultValue: false);
  static const String groqKey = String.fromEnvironment("GROQ_KEY",defaultValue: "");
  static const String broker_ip = String.fromEnvironment("BROKER_IP");
}