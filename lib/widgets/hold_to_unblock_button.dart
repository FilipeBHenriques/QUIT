import 'package:flutter/material.dart';
import 'package:quit/theme/neon_palette.dart';

const int holdDurationSeconds = 5;

class HoldToUnblockButton extends StatefulWidget {
  final Future<void> Function() onUnblocked;

  const HoldToUnblockButton({super.key, required this.onUnblocked});

  @override
  State<HoldToUnblockButton> createState() => _HoldToUnblockButtonState();
}

class _HoldToUnblockButtonState extends State<HoldToUnblockButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: holdDurationSeconds),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_triggered) {
        _triggered = true;
        widget.onUnblocked().then((_) {
          if (mounted) {
            _controller.reset();
            setState(() => _triggered = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHold() {
    if (!_triggered) _controller.forward();
  }

  void _stopHold() {
    if (!_triggered) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _stopHold(),
      onTapCancel: () => _stopHold(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final isHolding = progress > 0;
          final secondsLeft =
              (holdDurationSeconds - (progress * holdDurationSeconds).ceil())
                  .clamp(0, holdDurationSeconds);

          return Container(
            width: 88,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHolding
                    ? NeonPalette.rose.withValues(
                        alpha: 0.45 + progress * 0.40,
                      )
                    : NeonPalette.border,
                width: 0.5,
              ),
              boxShadow: isHolding
                  ? [
                      BoxShadow(
                        color: NeonPalette.rose.withValues(
                          alpha: 0.10 + progress * 0.22,
                        ),
                        blurRadius: 14,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                // Base
                Container(color: NeonPalette.surfaceSoft),

                // Fill bar
                FractionallySizedBox(
                  widthFactor: progress,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          NeonPalette.rose.withValues(alpha: 0.25),
                          NeonPalette.rose.withValues(alpha: 0.40),
                        ],
                      ),
                    ),
                  ),
                ),

                // Label
                Center(
                  child: Text(
                    isHolding ? '${secondsLeft}s' : 'Hold',
                    style: TextStyle(
                      color: isHolding
                          ? NeonPalette.rose
                          : NeonPalette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
