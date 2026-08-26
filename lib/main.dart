import 'package:enlatadora_web/layout/main_layout.dart';
import 'package:enlatadora_web/providers/mqtt_riverpod.dart';
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mqtt_client/mqtt_client.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: const MyHomePage(rootTopico: 'home/test/'),
    );
  }
}

class MyHomePage extends MqttThingScreen {
  const MyHomePage({super.key, required super.rootTopico})
    : super(name: "home");

  @override
  MqttThingScreenState<MqttThingScreen> createState() {
    return _MyHomePageState();
  }
}

class _MyHomePageState extends MqttThingScreenState<MyHomePage> {
  late final String ledTopic = "${widget.rootTopico}led";
  late final String readTopic = "${widget.rootTopico}read";

  String read = "0";

  @override
  void initState() {
    super.initState();
  }

  void mate() async {
    await ref.read(mqttProvider.future);
    await mqttNotifier.connect();
    mqttNotifier.subscribe(readTopic, (content) {
      setState(() {
        read = content;
      });

    }, qos: MqttQos.atMostOnce);
  }

  @override
  void subscribeToTopics() {
    mate();

  }

  @override
  void unsubscribeToTopics() {
    mqttNotifier.unsubscribe(readTopic);
    mqttNotifier.disconnect(manual: false);
  }

  @override
  Widget buildBody(BuildContext context) {
    return _body();
  }

  Widget _body() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text("Lectura: $read", style: GoogleFonts.caveat(color: Colors.white)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(foregroundColor: Colors.blueGrey[800]),
          onPressed: ()  {
            // debugPrint("It's me dad!");
            if (!mqttNotifier.isConnected()) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(content: Text("Not connected bro")),
              );
            }
            mqttNotifier.publish(ledTopic, "Hellooo");
          },
          child: Text(
            "Press meee",
            style: GoogleFonts.caveat(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
