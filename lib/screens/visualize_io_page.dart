import 'dart:convert';
import 'package:enlatadora_web/screens/mqtt_thing_screen.dart';
import 'package:flutter/material.dart';

class VisualizeIOPage extends MqttThingScreen {
  const VisualizeIOPage({
    required this.outputs,
    required this.inputs,
    required this.allowOutputOverride,
    super.key,
  }) : super(rootTopico: "");

  final List<bool> outputs;
  final List<bool> inputs;
  final bool allowOutputOverride;

  @override
  MqttThingScreenState<MqttThingScreen> createState() {
    return _VisualizeIOPageState();
  }
}

class _VisualizeIOPageState extends MqttThingScreenState<VisualizeIOPage> {
  String _searchQuery = "";
  _FilterOption _filter = _FilterOption.all;

  static const Color _outputActiveColor = Colors.amber;
  static const Color _inputActiveColor = Color(0xFF10B981); // Emerald green

  @override
  void subscribeToTopics() {}

  @override
  void unsubscribeToTopics() {}

  int get _activeOutputsCount =>
      widget.outputs.where((active) => active).length;
  int get _activeInputsCount =>
      widget.inputs.where((active) => active).length;

  void _toggleOutput(int index) {
    if (!widget.allowOutputOverride) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Output override is disabled. Enable 'Manual Output Override' above to change output state.",
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final input = {"Q$index": !widget.outputs[index]};
    mqttNotifier.publish("machine/IO/outputs/write", jsonEncode(input));
  }

  void _toggleOverride(bool value) {
    final data =
        value ? "AuthorizeOutputOverride" : "DisableOutputOverride";
    mqttNotifier.publish("machine/command", data);
  }

  @override
  Widget buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderControlCard(colorScheme),
          const SizedBox(height: 16),
          _buildStatsAndFilterBar(colorScheme),
          const SizedBox(height: 20),
          if (_filter == _FilterOption.all || _filter == _FilterOption.outputs)
            _buildOutputsSection(colorScheme),
          if (_filter == _FilterOption.all) const SizedBox(height: 24),
          if (_filter == _FilterOption.all || _filter == _FilterOption.inputs)
            _buildInputsSection(colorScheme),
        ],
      ),
    );
  }

  Widget _buildHeaderControlCard(ColorScheme colorScheme) {
    final isOverrideActive = widget.allowOutputOverride;

    return Card(
      elevation: 0,
      color: isOverrideActive
          ? colorScheme.errorContainer.withValues(alpha: 0.25)
          : colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverrideActive
              ? colorScheme.error.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
          width: isOverrideActive ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOverrideActive
                    ? colorScheme.error.withValues(alpha: 0.15)
                    : colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOverrideActive
                    ? Icons.lock_open_rounded
                    : Icons.lock_rounded,
                color: isOverrideActive
                    ? colorScheme.error
                    : colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "Manual Output Override",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isOverrideActive
                              ? colorScheme.error
                              : colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOverrideActive ? "ACTIVE" : "LOCKED",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOverrideActive
                                ? colorScheme.onError
                                : colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOverrideActive
                        ? "Outputs can be manually toggled via dashboard controls."
                        : "Outputs are locked to automatic PLC state.",
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isOverrideActive,
              activeThumbColor: colorScheme.error,
              activeTrackColor: colorScheme.errorContainer,
              onChanged: (val) => _toggleOverride(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsAndFilterBar(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        final statsCards = [
          _buildStatCard(
            title: "Digital Outputs (Q)",
            countText: "$_activeOutputsCount / ${widget.outputs.length} Active",
            icon: Icons.output_rounded,
            accentColor: _outputActiveColor,
            colorScheme: colorScheme,
          ),
          _buildStatCard(
            title: "Digital Inputs (I)",
            countText: "$_activeInputsCount / ${widget.inputs.length} Active",
            icon: Icons.input_rounded,
            accentColor: _inputActiveColor,
            colorScheme: colorScheme,
          ),
        ];

        return Column(
          children: [
            if (isNarrow)
              Column(
                children: [
                  statsCards[0],
                  const SizedBox(height: 8),
                  statsCards[1],
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: statsCards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: statsCards[1]),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search channel (e.g. Q1, I0)...",
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<_FilterOption>(
                  segments: const [
                    ButtonSegment(
                      value: _FilterOption.all,
                      label: Text("All"),
                    ),
                    ButtonSegment(
                      value: _FilterOption.outputs,
                      label: Text("Outputs"),
                    ),
                    ButtonSegment(
                      value: _FilterOption.inputs,
                      label: Text("Inputs"),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (newSelection) {
                    setState(() {
                      _filter = newSelection.first;
                    });
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String countText,
    required IconData icon,
    required Color accentColor,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                countText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutputsSection(ColorScheme colorScheme) {
    final filteredIndices = List.generate(widget.outputs.length, (i) => i)
        .where((i) {
      if (_searchQuery.isEmpty) return true;
      final tag = "Q$i".toLowerCase();
      final tagSub = "$i".toLowerCase();
      final q = _searchQuery.toLowerCase();
      return tag.contains(q) || tagSub == q;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: "Digital Outputs (Q)",
          subtitle: "Actuators, Valves & Relays",
          icon: Icons.output_rounded,
          countText: "${widget.outputs.length} Channels",
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        if (filteredIndices.isEmpty)
          _buildEmptyState("No matching output channels found.")
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisExtent: 125,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: filteredIndices.length,
            itemBuilder: (context, idx) {
              final index = filteredIndices[idx];
              final isActive = widget.outputs[index];
              return _buildOutputTile(index, isActive, colorScheme);
            },
          ),
      ],
    );
  }

  Widget _buildOutputTile(
      int index, bool isActive, ColorScheme colorScheme) {
    final isOverrideAllowed = widget.allowOutputOverride;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive
            ? _outputActiveColor.withValues(alpha: 0.12)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? _outputActiveColor.withValues(alpha: 0.8)
              : colorScheme.outlineVariant,
          width: isActive ? 1.8 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _outputActiveColor.withValues(alpha: 0.25),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toggleOutput(index),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Q$index",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isActive
                          ? _outputActiveColor
                          : colorScheme.onSurface,
                    ),
                  ),
                  Icon(
                    isActive ? Icons.lightbulb : Icons.lightbulb_outline,
                    size: 20,
                    color: isActive ? _outputActiveColor : colorScheme.outline,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? _outputActiveColor : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isActive ? "ON" : "OFF",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? _outputActiveColor : colorScheme.outline,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isOverrideAllowed)
                    Tooltip(
                      message: "Override locked",
                      child: Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: colorScheme.outline,
                      ),
                    )
                  else
                    Icon(
                      Icons.touch_app_outlined,
                      size: 14,
                      color: isActive ? _outputActiveColor : colorScheme.outline,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputsSection(ColorScheme colorScheme) {
    final filteredIndices = List.generate(widget.inputs.length, (i) => i)
        .where((i) {
      if (_searchQuery.isEmpty) return true;
      final tag = "I$i".toLowerCase();
      final tagSub = "$i".toLowerCase();
      final q = _searchQuery.toLowerCase();
      return tag.contains(q) || tagSub == q;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: "Digital Inputs (I)",
          subtitle: "Sensors, Switches & Feedback",
          icon: Icons.input_rounded,
          countText: "${widget.inputs.length} Channels",
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 12),
        if (filteredIndices.isEmpty)
          _buildEmptyState("No matching input channels found.")
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisExtent: 110,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: filteredIndices.length,
            itemBuilder: (context, idx) {
              final index = filteredIndices[idx];
              final isActive = widget.inputs[index];
              return _buildInputTile(index, isActive, colorScheme);
            },
          ),
      ],
    );
  }

  Widget _buildInputTile(
      int index, bool isActive, ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive
            ? _inputActiveColor.withValues(alpha: 0.12)
            : colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? _inputActiveColor.withValues(alpha: 0.8)
              : colorScheme.outlineVariant,
          width: isActive ? 1.8 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _inputActiveColor.withValues(alpha: 0.2),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "I$index",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isActive ? _inputActiveColor : colorScheme.onSurface,
                  ),
                ),
                Icon(
                  Icons.electric_bolt_rounded,
                  size: 18,
                  color: isActive ? _inputActiveColor : colorScheme.outline,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? _inputActiveColor : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isActive ? "ACTIVE" : "IDLE",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? _inputActiveColor : colorScheme.outline,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Sensor",
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required String countText,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 22, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Text(
            countText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }
}

enum _FilterOption { all, outputs, inputs }
