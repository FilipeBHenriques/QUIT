import 'package:flutter/material.dart';

// ============================================================================
// MINES GAME CONSTANTS - ALL CONFIGURABLE VALUES
// ============================================================================

class MinesConstants {
  // ============================================================================
  // GAME RULES
  // ============================================================================

  /// Grid size (5x5)
  static const int gridSize = 5;

  /// Total number of tiles
  static const int totalTiles = gridSize * gridSize;

  /// Number of bombs in the grid
  static const int bombCount = 5;

  /// Number of diamonds (safe tiles)
  static const int diamondCount = totalTiles - bombCount;

  /// Multiplier for each diamond found (1/10 = 0.1)
  static const double multiplierPerDiamond = 0.1;

  // ============================================================================
  // LAYOUT - PERCENTAGE BASED
  // ============================================================================

  /// Grid center X position (percentage of screen width)
  static const double gridCenterX = 0.5;

  /// Grid center Y position (percentage of screen height)
  static const double gridCenterY = 0.65;

  /// Grid width (percentage of screen width)
  static const double gridWidthPercent = 0.75;

  /// Spacing between tiles (percentage of tile size)
  static const double tileSpacingPercent = 0.08;

  /// Top bar height (percentage of screen height)
  static const double topBarHeightPercent = 0.12;

  /// Bottom controls height (percentage of screen height)
  static const double bottomControlsHeightPercent = 0.25;

  /// Stats display Y position (percentage of screen height)
  static const double statsDisplayY = 0.15;

  // ============================================================================
  // COLORS - BLACK & WHITE THEME
  // ============================================================================

  /// Background color
  static const Color backgroundColor = Colors.black;

  /// Tile color (unrevealed)
  static const Color tileColor = Color(0xFF1A1A1A);

  /// Tile border color
  static const Color tileBorderColor = Color(0xFF333333);

  /// Tile hover/selected color
  static const Color tileHoverColor = Color(0xFF2A2A2A);

  /// Diamond color (success)
  static const Color diamondColor = Colors.white;

  /// Bomb color (danger)
  static const Color bombColor = Color(0xFFFF4444);

  /// Win accent color
  static const Color winColor = Colors.greenAccent;

  /// Lose accent color
  static const Color loseColor = Colors.redAccent;

  /// Text color primary
  static const Color textColorPrimary = Colors.white;

  /// Text color secondary
  static const Color textColorSecondary = Color(0xFFAAAAAA);

  /// Button color primary
  static const Color buttonColorPrimary = Colors.white;

  /// Button color secondary
  static const Color buttonColorSecondary = Color(0xFF2A2A2A);

  // ============================================================================
  // SIZES
  // ============================================================================

  /// Tile border width
  static const double tileBorderWidth = 1.0;

  /// Tile border radius
  static const double tileBorderRadius = 8.0;

  /// Icon size multiplier (relative to tile size)
  static const double iconSizeMultiplier = 0.5;

  // ============================================================================
  // ANIMATIONS
  // ============================================================================

  /// Tile reveal animation duration (milliseconds)
  static const int revealAnimationDuration = 300;

  /// Tile reveal animation stagger delay (milliseconds)
  static const int revealAnimationStagger = 50;

  /// Win/lose animation duration (milliseconds)
  static const int resultAnimationDuration = 800;

  /// Pulse animation duration (milliseconds)
  static const int pulseAnimationDuration = 1500;

  /// Scale animation intensity
  static const double scaleAnimationIntensity = 1.2;

  /// Glow blur radius
  static const double glowBlurRadius = 30.0;

  /// Glow opacity
  static const double glowOpacity = 0.8;

  // ============================================================================
  // TEXT STYLES
  // ============================================================================

  /// Title text size
  static const double titleTextSize = 20.0;

  /// Title letter spacing
  static const double titleLetterSpacing = 4.0;

  /// Stats text size
  static const double statsTextSize = 14.0;

  /// Stats letter spacing
  static const double statsLetterSpacing = 2.0;

  /// Big number text size
  static const double bigNumberTextSize = 48.0;

  /// Button text size
  static const double buttonTextSize = 16.0;

  /// Button letter spacing
  static const double buttonLetterSpacing = 2.0;

  // ============================================================================
  // GAME TEXT
  // ============================================================================

  /// Game title
  static const String gameTitle = 'MINES';

  /// Diamonds found label
  static const String diamondsFoundLabel = 'DIAMONDS';

  /// Multiplier label
  static const String multiplierLabel = 'MULTIPLIER';

  /// Potential win label
  static const String potentialWinLabel = 'POTENTIAL WIN';

  /// Cash out button text
  static const String cashOutButton = 'CASH OUT';

  /// Reset button text
  static const String resetButton = 'RESET';

  /// Winner message
  static const String winnerMessage = 'WINNER!';

  /// Loser message
  static const String loserMessage = 'BOOM!';

  /// Select tiles instruction
  static const String selectTilesInstruction = 'SELECT TILES TO REVEAL';

  /// All clear message
  static const String allClearMessage = 'ALL DIAMONDS FOUND!';

  // ============================================================================
  // GAME LOGIC
  // ============================================================================

  /// Calculate multiplier based on diamonds found
  static double calculateMultiplier(int diamondsFound) {
    return 1.0 + (diamondsFound * multiplierPerDiamond);
  }

  /// Calculate potential winnings
  static int calculatePotentialWin(int betAmount, int diamondsFound) {
    final multiplier = calculateMultiplier(diamondsFound);
    return (betAmount * multiplier).round();
  }

  /// Calculate actual winnings (bet + profit)
  static int calculateActualWin(int betAmount, int diamondsFound) {
    final potentialWin = calculatePotentialWin(betAmount, diamondsFound);
    return potentialWin; // This is the total amount won
  }

  /// Calculate profit (win minus bet)
  static int calculateProfit(int betAmount, int diamondsFound) {
    final actualWin = calculateActualWin(betAmount, diamondsFound);
    return actualWin - betAmount;
  }

  /// Format time as MM:SS
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Format multiplier (e.g., "1.5x")
  static String formatMultiplier(double multiplier) {
    return '${multiplier.toStringAsFixed(1)}x';
  }
}

// ============================================================================
// TILE STATES
// ============================================================================

enum TileState {
  hidden, // Not yet revealed
  revealed, // Revealed (diamond or bomb)
  exploding, // Bomb animation in progress
}

enum TileType {
  diamond, // Safe tile
  bomb, // Mine/bomb tile
}
