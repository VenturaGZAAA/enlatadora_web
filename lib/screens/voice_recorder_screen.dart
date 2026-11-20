import 'dart:developer';
import 'package:material_ui/material_ui.dart';

import 'package:enlatadora_web/models/app_config.dart';
import 'package:enlatadora_web/providers/recording_provider.dart';
import 'package:enlatadora_web/providers/transcriptions_provider.dart';
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:enlatadora_web/widgets/groq_voice_recorder.dart';
import 'package:enlatadora_web/widgets/voice_recorder_button.dart';

class VoiceRecorderScreen extends MqttThingScreen {
  const VoiceRecorderScreen({
    super.key,
  }) : super(rootTopico: "");

  @override
  MqttThingScreenState<MqttThingScreen> createState() {
    return _VoiceRecorderScreenState();
  }
}

class _VoiceRecorderScreenState
    extends MqttThingScreenState<VoiceRecorderScreen> {
  String? _match;

  static const String espListeningTopic = "voice/keyword/listening";
  bool _espListening = false;

  @override
  void subscribeToTopics() {
    mqttNotifier.subscribe(espListeningTopic, (payload) {
      try {
        bool? value = switch (payload) {
          "0" => false,
          "1" => true,
          _ => null,
        };
        if (value == null) {
          throw ("Invalid listening payload");
        }
        setState(() {
          _espListening = value;
        });
        if (_espListening && AppConfig.espBuild) {
          ref.read(recordingProvider.notifier).recordingStart();
        }
      } catch (e) {
        log("Exception at voice listening: $e");
      }
    });
    if (!AppConfig.espBuild) {
      mqttNotifier.publish("voice/keyword/command", "voiceOff");
    }
  }

  @override
  void unsubscribeToTopics() {
    mqttNotifier.unsubscribe(espListeningTopic);
  }

  @override
  Widget buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (AppConfig.groqKey.length < 5 && !AppConfig.espBuild) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          color: colorScheme.errorContainer,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.key_off_rounded,
                  size: 44,
                  color: colorScheme.onErrorContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  "Groq API Key Missing",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please set GROQ_KEY in app config to enable cloud speech recognition.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget? espButton;

    if (AppConfig.espBuild) {
      final buttonText = _espListening ? 'Stop Listening' : 'Start Listening';
      final buttonIcon = _espListening
          ? const Icon(Icons.stop_rounded)
          : const Icon(Icons.mic_rounded);

      espButton = VoiceKeywordButton(
        isListening: _espListening,
        buttonText: buttonText,
        buttonIcon: buttonIcon,
        toStart: () {
          mqttNotifier.publish("voice/keyword/command", "voiceOn");
        },
        toStop: () {
          mqttNotifier.publish("voice/keyword/command", "voiceOff");
        },
      );
    }

    final transcriptions = ref.watch(transcriptionsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar / Command Match Indicator
          if (_match != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Command: ",
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _match!.toUpperCase(),
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Main Transcription View Card
          Expanded(
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.record_voice_over_outlined,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Live Transcriptions",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        if (transcriptions.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${transcriptions.length}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 20),
                    Expanded(
                      child: transcriptions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.graphic_eq_rounded,
                                    size: 48,
                                    color: colorScheme.outline.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Ready to Record",
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Voice commands will appear here in real-time.",
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: transcriptions.length,
                              reverse: true,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                // Show newest first
                                final item =
                                    transcriptions[transcriptions.length -
                                        1 -
                                        index];
                                final timeStr =
                                    "${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}:${item.time.second.toString().padLeft(2, '0')}";

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.message,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: colorScheme.onSurface,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bottom Voice Action Button Area
          Center(
            child: espButton ??
                GroqVoiceRecorder(
                  groqApiKey: AppConfig.groqKey,
                  keywords: const [
                    "stop",
                    "disable",
                    "detener",
                    "desactivar",
                    "start",
                    "enable",
                    "inicia",
                    "arranca",
                    "pause",
                    "emergency",
                    "emergencia",
                    "pausa",
                    "resume",
                    "continue",
                    "continua",
                    "reanuda",
                  ],
                  onKeywordDetected: (result) {
                    log("Voice result: $result");
                    setState(() {
                      _match = result;
                    });
                    if (result != null) {
                      mqttNotifier.publish("machine/command", result);
                    }
                  },
                ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
