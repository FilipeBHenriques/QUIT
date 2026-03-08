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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NeonPalette.border),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: NeonPalette.text),
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: NeonPalette.border),
              ),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                      color: NeonPalette.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'BETTING: $bettingTime',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
