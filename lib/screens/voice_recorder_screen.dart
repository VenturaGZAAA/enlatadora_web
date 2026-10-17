import 'package:enlatadora_web/providers/recording_provider.dart';
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:flutter/material.dart';

// import 'package:mqtt_client/mqtt_client.dart';
// import 'package:enlatadora_web/providers/mqtt_riverpod.dart';
import 'package:enlatadora_web/widgets/groq_voice_recorder.dart';

// import 'package:enlatadora_web/widgets/helpers.dart';
// import 'dart:convert';
import 'package:enlatadora_web/models/mock_data.dart';
import 'dart:developer';
import 'package:enlatadora_web/models/app_config.dart';
import 'package:enlatadora_web/widgets/voice_recorder_button.dart';

class VoiceRecorderScreen extends MqttThingScreen {
  const VoiceRecorderScreen({
    required this.trans,
    required this.addTrans,
    super.key,
  }) : super(rootTopico: "");

  final List<MockData> trans;
  final void Function(String) addTrans;

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
    if (AppConfig.espBuild) {
      mqttNotifier.subscribe(espListeningTopic, (payload) {
        try {
          bool value = bool.parse(payload);
          setState(() {
            _espListening = value;
          });
          if (_espListening) {
            ref.read(recordingProvider.notifier).recordingStart();
          }
        } finally {}
      });
    }
  }

  @override
  void unsubscribeToTopics() {
    if (AppConfig.espBuild) {
      mqttNotifier.unsubscribe(espListeningTopic);
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    if (AppConfig.groqKey.length < 5 && !AppConfig.espBuild) {
      return Center(
        child: Text(
          "GROQ_KEY not found in config file",
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    Widget? espButton;

    if (AppConfig.espBuild) {
      final buttonText = _espListening ? 'Press to Stop' : 'Hold to Record';
      final buttonIcon = _espListening
          ? const Icon(Icons.stop)
          : const Icon(Icons.mic);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.max,
      spacing: 15.0,
      children: [
        Expanded(
          child: Center(
            child: Container(
              padding: EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _match != null
                    ? Colors.lightGreenAccent.withAlpha(55)
                    : null,
              ),
              child: Text(_match ?? "No matches found"),
            ),
          ),
        ),
        if (widget.trans.isNotEmpty)
          SizedBox(
            height: 150,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255.0 * 0.2).toInt()),
                    spreadRadius: 4,
                    blurRadius: 10,
                  ),
                ],
              ),

              child: ListView.builder(
                itemCount: widget.trans.length,
                reverse: false,
                itemBuilder: (ctx, index) =>
                    Center(child: widget.trans[index].view()),
              ),
            ),
          ),

        ?espButton,

        if (espButton == null)
          GroqVoiceRecorder(
            groqApiKey: AppConfig.groqKey,
            keywords: [
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
            ],
            onTranscriptionReceived: widget.addTrans,
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
      ],
    );
  }
}
