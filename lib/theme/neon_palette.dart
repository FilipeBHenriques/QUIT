import 'package:flutter/material.dart';

class NeonPalette {
  static const Color bg = Color(0xFF05070B);
  static const Color surface = Color(0xFF0C1018);
  static const Color surfaceSoft = Color(0xFF111827);
  static const Color border = Color(0xFF1F2937);
  static const Color text = Color(0xFFF3F4F6);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color cyan = Color(0xFF22D3EE);
  static const Color mint = Color(0xFF34D399);
  static const Color rose = Color(0xFFFB7185);
  static const Color amber = Color(0xFFFBBF24);

  static LinearGradient pageGlow = const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF061018), Color(0xFF07090E), Color(0xFF0B111A)],
  );
}
