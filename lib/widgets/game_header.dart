import 'package:flutter/material.dart';
import 'package:quit/theme/neon_palette.dart';

class GameHeader extends StatelessWidget {
  final String title;
  final String bettingTime;
  final VoidCallback onBack;

  const GameHeader({
    super.key,
    required this.title,
    required this.bettingTime,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NeonPalette.bg,
        border: Border(
          bottom: BorderSide(color: NeonPalette.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          // Back button — minimal square
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: NeonPalette.surfaceSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NeonPalette.border, width: 0.5),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: NeonPalette.textMuted,
                size: 14,
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 5,
                    color: NeonPalette.text,
                  ),
                ),
                const SizedBox(height: 6),
                // Bet badge
                _BettingBadge(time: bettingTime),
              ],
            ),
          ),

          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _BettingBadge extends StatelessWidget {
  final String time;
  const _BettingBadge({required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: NeonPalette.rose.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NeonPalette.rose.withValues(alpha: 0.25),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: NeonPalette.rose.withValues(alpha: 0.10),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: NeonPalette.rose,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: NeonPalette.rose.withValues(alpha: 0.8),
                  blurRadius: 5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'BETTING  $time',
            style: TextStyle(
              color: NeonPalette.rose.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
