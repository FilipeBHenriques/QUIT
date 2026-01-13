import 'package:flutter/material.dart';
import 'dart:async';

const int holdDurationSeconds = 5;

class HoldToUnblockButton extends StatefulWidget {
  final Future<void> Function() onUnblocked;

  const HoldToUnblockButton({super.key, required this.onUnblocked});

  @override
  State<HoldToUnblockButton> createState() => _HoldToUnblockButtonState();
}

class _HoldToUnblockButtonState extends State<HoldToUnblockButton> {
  bool _holding = false;
  Timer? _timer;
  int _secondsHeld = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _holding = true;
          _secondsHeld = 0;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _secondsHeld++;
          });
          if (_secondsHeld >= holdDurationSeconds) {
            timer.cancel();
            widget.onUnblocked().then((_) {
              if (mounted) {
                setState(() {
                  _holding = false;
                  _secondsHeld = 0;
                });
              }
            });
          }
        });
      },
      onTapUp: (_) {
        _timer?.cancel();
        setState(() {
          _holding = false;
          _secondsHeld = 0;
        });
      },
      onTapCancel: () {
        _timer?.cancel();
        setState(() {
          _holding = false;
          _secondsHeld = 0;
        });
      },
      child: Container(
        width: 80,
        height: 40,
        decoration: BoxDecoration(
          color: _holding ? Colors.redAccent : Colors.grey[700],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            _holding ? '${holdDurationSeconds - _secondsHeld}s' : 'Hold',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
