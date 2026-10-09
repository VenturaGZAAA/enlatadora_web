import 'package:enlatadora_web/providers/recording_provider.dart';
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:flutter/material.dart';

// import 'package:mqtt_client/mqtt_client.dart';
// import 'package:enlatadora_web/providers/mqtt_riverpod.dart';
import 'package:enlatadora_web/widgets/groq_voice_recorder.dart';

// import 'package:enlatadora_web/widgets/helpers.dart';
// import 'dart:convert';
import 'dart:developer';
import 'package:enlatadora_web/models/app_config.dart';

class VoiceRecorderScreen extends MqttThingScreen {
  const VoiceRecorderScreen({super.key}) : super(rootTopico: "");

  @override
  MqttThingScreenState<MqttThingScreen> createState() {
    return _VoiceRecorderScreenState();
  }
}

class _VoiceRecorderScreenState
    extends MqttThingScreenState<VoiceRecorderScreen> {
  String? _match;
  final List<_MockData> wordsFound = [];

  @override
  void subscribeToTopics() {
    // TODO: implement subscribeToTopics
  }

  @override
  void unsubscribeToTopics() {
    // TODO: implement unsubscribeToTopics
  }

  @override
  Widget buildBody(BuildContext context) {
    if (AppConfig.espBuild) {
      return Center(
        child: const Text(
          "W.I.P",
          style: TextStyle(color: Colors.red, fontSize: 32),
        ),
      );
    }

    if (AppConfig.groqKey.length < 5) {
      return Center(
        child: Text(
          "GROQ_KEY not found in config file",
          style: TextStyle(color: Colors.red),
        ),
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
        if (wordsFound.isNotEmpty)
          SizedBox(
            height: 150,
            child: Container(
              decoration: BoxDecoration(
                // color: const Color.fromARGB(65, 158, 158, 158),
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
                itemCount: wordsFound.length,
                itemBuilder: (ctx, index) =>
                    Center(child: wordsFound[index].view()),
              ),
            ),
          ),

        GroqVoiceRecorder(
          groqApiKey: AppConfig.groqKey,
          keywords: ["stop", "paro", "reset", "reinicia", "start", "arranque"],
          onTranscriptionReceived: (transcription) {
            setState(() {
              wordsFound.add(_MockData(DateTime.now(), transcription));
              if (wordsFound.length>10) {
                wordsFound.removeAt(0);
              }
            });
          },
          onKeywordDetected: (result) {
            log("Voice result: $result");
            setState(() {
              _match = result;
            });
          },
        ),
      ],
    );
  }
}

class _MockData {
  const _MockData(this.time, this.message);

  final DateTime time;
  final String message;

  Widget view() {
    return ListTile(
      title: Text(message),
      subtitle: Text("${time.hour}-${time.minute}-${time.second}"),
    );
  }
}
