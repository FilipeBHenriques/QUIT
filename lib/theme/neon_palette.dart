import 'package:flutter/material.dart';

class NeonPalette {
  // Backgrounds — near-black with indigo undertone
  static const Color bg = Color(0xFF020408);
  static const Color surface = Color(0xFF080A10);
  static const Color surfaceSoft = Color(0xFF0C0E16);
  static const Color surfaceElevated = Color(0xFF10121A);

  // Borders — barely-there lines
  static const Color border = Color(0xFF14161E);
  static const Color borderBright = Color(0xFF1E2130);

  // Text
  static const Color text = Color(0xFFF0F2F8);
  static const Color textMuted = Color(0xFF6B7A9A);  // was 0xFF3D4558 — bumped for legibility
  static const Color textDim = Color(0xFF323848);

  // Neon accents — electric, saturated
  static const Color cyan = Color(0xFF00F0FF);   // Electric cyan  — brand / Mines
  static const Color mint = Color(0xFF00D68F);   // Neon mint      — wins / Blackjack
  static const Color rose = Color(0xFFFF1A5C);   // Neon rose      — losses / Roulette
  static const Color amber = Color(0xFFFFAB00);  // Gold           — bonuses
  static const Color violet = Color(0xFF9B5CFF); // Electric violet — home icon

  // Gradients
  static LinearGradient pageGlow = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF05060D), Color(0xFF020408), Color(0xFF080910)],
  );

  // Convenience glow helper
  static List<BoxShadow> neonGlow(Color color, {double intensity = 1.0}) => [
    BoxShadow(
      color: color.withValues(alpha: 0.55 * intensity),
      blurRadius: 18,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: color.withValues(alpha: 0.20 * intensity),
      blurRadius: 40,
      spreadRadius: 4,
    ),
  ];
}
