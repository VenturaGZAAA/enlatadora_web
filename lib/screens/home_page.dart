import 'dart:convert';
import 'dart:developer';

import 'package:enlatadora_web/models/app_config.dart';
import 'package:enlatadora_web/models/wifi_data.dart';
import 'package:enlatadora_web/providers/mqtt_riverpod.dart';
import 'package:enlatadora_web/providers/recording_provider.dart';
import 'package:enlatadora_web/screens/visualize_io_page.dart';
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:enlatadora_web/screens/voice_recorder_screen.dart';

import 'package:enlatadora_web/widgets/mqtt_config_button.dart';
import 'package:enlatadora_web/widgets/reset_button.dart';
import 'package:enlatadora_web/widgets/wifi_config_page.dart';
import 'package:flutter/material.dart';
import 'package:enlatadora_web/models/mock_data.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:web_socket_client/web_socket_client.dart' as ws;
import 'package:enlatadora_web/providers/home_state_provider.dart';

class HomeScreen extends MqttThingScreen {
  const HomeScreen({super.key, required super.rootTopico})
    : super(name: "home");

  @override
  MqttThingScreenState<MqttThingScreen> createState() {
    return _HomePageState();
  }
}

class _HomePageState extends MqttThingScreenState<HomeScreen> {
  final controllerSocket = ws.WebSocket(Uri.parse(AppConfig.controller_ws));
  final List<MockData> controllerTx = [];
  final List<MockData> controllerRx = [];
  ws.ConnectionState _wsState = const ws.Connecting();
  final TextEditingController _chatInputController = TextEditingController();
  static bool panelControlHome = true;
  static const String wifiStateTopic = "config/wifi/state";
  static const numOutputs = 19;
  static const numInputs = 8;
  static const String machineStateTopic = "machine/state/read";

  static const String commandsTopic = "machine/command";

  static const String outputsReadTopic = "machine/IO/outputs/read";
  static const String inputsReadTopic = "machine/IO/inputs/read";

  final List<bool> outputs = List.filled(numOutputs, false);
  final List<bool> inputs = List.filled(numInputs, false);
  bool? _machineHeartBeating;
  bool _machineRunning = false;
  bool _machinePaused = false;
  String? _stage;
  bool _authorizedSystem = false;
  bool _allowOutputOverride = false;

  bool _wifiUpdated = false;
  WiFiState? _wiFiState;

  static const String voiceTranscriptionsTopic = "voice/keyword/transcription";
  final List<MockData> _transcriptions = [];
  static const int maxTranscriptions = 20;

  void addTranscription(String transcription) {
    setState(() {
      _transcriptions.add(MockData(DateTime.now(), transcription));
    });

    while (_transcriptions.length > maxTranscriptions) {
      _transcriptions.removeAt(0);
    }
  }

  late List<Widget Function()> screens = [_home, _recorder, _configBody];

  void mate() async {
    await ref.read(mqttProvider.future);
    await mqttNotifier.connect();

    mqttNotifier.subscribe(wifiStateTopic, (content) {
      try {
        setState(() {
          _wiFiState = WiFiState.fromJson(jsonDecode(content));
        });
      } finally {}
    }, qos: MqttQos.atLeastOnce);

    mqttNotifier.subscribe(voiceTranscriptionsTopic, addTranscription);
  }

  @override
  void subscribeToTopics() {
    mate();

    mqttNotifier.subscribe(machineStateTopic, (payload) {
      final state = jsonDecode(payload) as Map<String, dynamic>;
      setState(() {
        final heartBeating = state["machineHeartBeating"];
        if (heartBeating is bool) {
          _machineHeartBeating = heartBeating;
        } else {
          _machineHeartBeating = null;
        }
        final running = state["running"];
        if (running is bool) {
          _machineRunning = running;
        }
        final paused = state["paused"];
        if (paused is bool) {
          _machinePaused = paused;
        }
        final stage = state["stage"];
        if (stage is String) {
          _stage = stage;
        }
        final authorized = state["authorizedSystem"];
        if (authorized is bool) {
          _authorizedSystem = authorized;
        }
        final outputOverride = state["output_override"];
        if (outputOverride is bool) {
          _allowOutputOverride = outputOverride;
        }
      });
    });

    mqttNotifier.subscribe(outputsReadTopic, (payload) {
      final state = jsonDecode(payload) as Map<String, dynamic>;
      if (state.length != numOutputs) {
        log("Outputs length does not match");
      }

      for (int x = 0; x < numOutputs; x++) {
        final value = state["Q$x"];
        if (value is bool) {
          setState(() => outputs[x] = value);
        } else {
          log("Missing or invalid value for Q$x");
        }
      }
    });

    mqttNotifier.subscribe(inputsReadTopic, (payload) {
      final state = jsonDecode(payload) as Map<String, dynamic>;
      if (state.length != numInputs) {
        log("Inputs length does not match");
      }

      for (int x = 0; x < numInputs; x++) {
        final value = state["I$x"];
        if (value is bool) {
          setState(() => inputs[x] = value);
        } else {
          log("Missing or invalid value for I$x");
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();

    controllerSocket.connection.listen((state) {
      log("Controller WS state: $state");
      if (mounted) {
        setState(() {
          _wsState = state;
        });
      }
    });

    controllerSocket.messages.listen((message) {
      log("Controller message: $message");
      if (mounted) {
        setState(() {
          controllerRx.add(MockData(DateTime.now(), message.toString()));
        });
      }
    });
  }

  @override
  void unsubscribeToTopics() {
    mqttNotifier.unsubscribe(wifiStateTopic);
    mqttNotifier.unsubscribe(machineStateTopic);
    mqttNotifier.unsubscribe(outputsReadTopic);
    mqttNotifier.unsubscribe(inputsReadTopic);
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    super.dispose();
    mqttNotifier.disconnect(manual: false);
    controllerSocket.close();
  }

  @override
  Widget buildBody(BuildContext context) {
    return _layout();
  }

  Widget _layout() {
    if (_wiFiState != null && _wiFiState!.isInvalid() && !_wifiUpdated) {
      setState(() {
        ref.read(homeProvider.notifier).goToConfig();
        _wifiUpdated = true;
      });
    }
    final width = MediaQuery.sizeOf(context).width;

    Widget? floatingActionButton =
        (!isWide(width) && ref.read(homeProvider.notifier).isHome)
        ? IconButton.outlined(
            onPressed: () {
              setState(() {
                panelControlHome = !panelControlHome;
              });
            },
            icon: Icon(Icons.arrow_forward_ios_outlined),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(super.widget.name),
        actions: [
          ...switch (ref.read(homeProvider)) {
            HomePage.control => [],
            HomePage.voice => [
              Icon(
                Icons.record_voice_over,
                color: ref.watch(recordingProvider) ? Colors.lightGreen : null,
              ),
              SizedBox(width: 5),
            ],
            HomePage.config => [MqttConfigButton()],
          },
        ],
      ),
      body: Center(
        child: AnimatedContainer(
          duration: Duration(milliseconds: 1000),
          curve: Curves.bounceIn,
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusCard(),
              const Divider(color: Colors.grey),
              const SizedBox(height: 16),
              Expanded(child: screens[ref.watch(homeProvider).index].call()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: ref.watch(homeProvider).index,
        onDestinationSelected: (index) {
          ref.read(homeProvider.notifier).page = HomePage.values[index];
          if (ref.read(homeProvider) == HomePage.config) {
            _wiFiState = null;
          }
        },
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.home),
            selectedIcon: Icon(Icons.home_outlined),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.mic),
            selectedIcon: Icon(Icons.mic_outlined),
            label: "Voice",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            selectedIcon: Icon(Icons.settings_outlined),
            label: "Settings",
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _statusCard() {
    final colorScheme = Theme.of(context).colorScheme;

    final statusColor = _machineRunning
        ? (_machinePaused ? Colors.amber.shade800 : Colors.green.shade700)
        : colorScheme.outline;
    final statusText = _machineRunning
        ? (_machinePaused ? "PAUSED" : "RUNNING")
        : "STOPPED";

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Stage",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _stage ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Authorized",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Checkbox(value: _authorizedSystem, onChanged: (_) {}),
              ],
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _machineRunning
                        ? (_machinePaused
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled)
                        : Icons.stop_circle,
                    size: 18,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset? _dragStartPosition;

  bool isWide(double width) {
    return width > 600;
  }

  Widget _home() {
    final width = MediaQuery.sizeOf(context).width;
    if (isWide(width)) {
      return Row(
        spacing: 15,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _dashboardBody()),
          Expanded(child: _generateIOView()),
        ],
      );
    }

    return Listener(
      onPointerDown: (event) {
        _dragStartPosition = event.position;
      },
      onPointerUp: (event) {
        log("Start position: $_dragStartPosition");

        if (_dragStartPosition == null) return;

        final delta = event.position - _dragStartPosition!;
        log("Raw delta: ${delta.dx}");

        if (delta.dx.abs() > 50.0) {
          setState(() {
            panelControlHome = !panelControlHome;
          });
        }
        _dragStartPosition = null;
      },
      child: AnimatedContainer(
        curve: Curves.bounceIn,
        duration: const Duration(milliseconds: 2000),
        child: panelControlHome ? _dashboardBody() : _generateIOView(),
      ),
    );
  }

  Widget _dashboardBody() {
    if (_machineHeartBeating == null) {
      const size = 60.0;
      return Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          SizedBox.fromSize(
            size: const Size.square(size),
            child: const Expanded(child: CircularProgressIndicator()),
          ),
          const Text("Esperando conexion..."),
        ],
      );
    }

    if (!_machineHeartBeating!) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(height: 16),
              Text(
                "Controller Offline",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Ensure the controller is powered on and the RT/TX cables are connected correctly.",
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    if (!_machineRunning) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                mqttNotifier.publish(commandsTopic, "ForceAuthorization");
                mqttNotifier.publish(commandsTopic, "Start");
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 48),
              label: const Text(
                "START MACHINE",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _machinePaused
                  ? Colors.blue.shade700
                  : Colors.amber.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              if (_machinePaused) {
                mqttNotifier.publish(commandsTopic, "Resume");
              } else {
                mqttNotifier.publish(commandsTopic, "Pause");
              }
            },
            icon: Icon(
              _machinePaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 40,
            ),
            label: Text(
              _machinePaused ? "RESUME" : "PAUSE",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              mqttNotifier.publish(commandsTopic, "Stop");
            },
            icon: const Icon(Icons.stop_rounded, size: 40),
            label: const Text(
              "STOP MACHINE",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _generateIOView() {
    return VisualizeIOPage(
      allowOutputOverride: _allowOutputOverride,
      outputs: outputs,
      inputs: inputs,
    );
  }

  Widget _recorder() {
    return VoiceRecorderScreen(
      trans: _transcriptions,
      addTrans: addTranscription,
    );
  }

  Widget _configBody() {
    return ListView(
      children: [
        // _buildChatWindow(),
        // const Divider(color: Colors.grey),
        // const SizedBox(height: 16),
        WifiConfigPage(),
        const SizedBox(height: 16),
        const Divider(color: Colors.grey),
        ResetButton(),
      ],
    );
  }

  void _sendMessage() {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;

    controllerSocket.send(text);
    setState(() {
      controllerTx.add(MockData(DateTime.now(), text));
    });
    _chatInputController.clear();
  }

  Widget _buildConnectionInfo() {
    return switch (_wsState) {
      ws.Connected() => const SizedBox.shrink(),
      ws.Disconnected() => _buildInfoChip("Controller WS disconnected"),
      ws.Connecting() => _buildInfoChip("Connecting to Controller WS..."),
      ws.Reconnecting() => _buildInfoChip("Reconnecting to Controller WS..."),
      ws.Disconnecting() => _buildInfoChip(
        "Disconnecting from Controller WS...",
      ),
      _ => _buildInfoChip("Controller WS offline"),
    };
  }

  Widget _buildInfoChip(String statusText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageItem(_ChatMessage chatMsg) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTx = chatMsg.isTx;
    final timeStr =
        "${chatMsg.data.time.hour.toString().padLeft(2, '0')}:${chatMsg.data.time.minute.toString().padLeft(2, '0')}:${chatMsg.data.time.second.toString().padLeft(2, '0')}";

    final bubbleBg = isTx
        ? colorScheme.primaryContainer
        : colorScheme.secondaryContainer;
    final textColor = isTx
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSecondaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: isTx
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isTx ? 12 : 2),
                bottomRight: Radius.circular(isTx ? 2 : 12),
              ),
            ),
            child: Column(
              crossAxisAlignment: isTx
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isTx
                            ? colorScheme.primary
                            : colorScheme.secondary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isTx ? "Tx" : "Rx",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isTx
                              ? colorScheme.onPrimary
                              : colorScheme.onSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeStr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: textColor.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  chatMsg.data.message,
                  style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatWindow() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final allMessages = [
      ...controllerTx.map((m) => _ChatMessage(data: m, isTx: true)),
      ...controllerRx.map((m) => _ChatMessage(data: m, isTx: false)),
    ]..sort((a, b) => b.data.time.compareTo(a.data.time));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 350,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Controller Direct Chat",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildConnectionInfo(),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: allMessages.isEmpty
                    ? Center(
                        child: Text(
                          "No messages exchanged yet",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: allMessages.length,
                        itemBuilder: (context, index) {
                          final msg = allMessages[index];
                          return _buildChatMessageItem(msg);
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    decoration: InputDecoration(
                      hintText: "Type message to controller...",
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  tooltip: "Send message",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.data, required this.isTx});

  final MockData data;
  final bool isTx;
}
