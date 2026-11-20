import 'package:material_ui/material_ui.dart';

class VoiceKeywordButton extends StatefulWidget {
  const VoiceKeywordButton({
    super.key,
    required this.isListening,
    required this.buttonText,
    required this.buttonIcon,
    required this.toStart,
    required this.toStop,
  });

  final String buttonText;
  final Widget buttonIcon;
  final void Function()? toStart;
  final void Function()? toStop;
  final bool isListening;

  @override
  State<VoiceKeywordButton> createState() => _VoiceKeywordButtonState();
}

class _VoiceKeywordButtonState extends State<VoiceKeywordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isListening) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VoiceKeywordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final backgroundColor = widget.isListening
        ? colorScheme.error
        : colorScheme.primary;
    final foregroundColor = widget.isListening
        ? colorScheme.onError
        : colorScheme.onPrimary;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = widget.isListening ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: widget.isListening
                  ? [
                      BoxShadow(
                        color: colorScheme.error.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 3,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: child,
          ),
        );
      },
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        onPressed: () {
          if (widget.isListening) {
            widget.toStop?.call();
          } else {
            widget.toStart?.call();
          }
        },
        icon: widget.buttonIcon,
        label: Text(
          widget.buttonText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
