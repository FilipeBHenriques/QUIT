import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:quit/game_result.dart';
import 'mines_constants.dart';
import 'mines_grid.dart';

// ============================================================================
// MINES GAME - MAIN GAME CLASS
// ============================================================================

class MinesGame extends FlameGame {
  final Function(GameResult)? onGameComplete;
  final int betAmount;

  MinesGame({this.onGameComplete, required this.betAmount});

  // Game state
  late MinesGrid grid;
  int diamondsFound = 0;
  bool isGameOver = false;
  bool hasWon = false;

  // UI Components
  late TextComponent diamondsText;
  late TextComponent multiplierText;
  late TextComponent potentialWinText;
  late TextComponent instructionText;

  // Stream for stats updates
  final _statsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get statsStream => _statsController.stream;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _initializeGrid();
    _initializeUI();
    _updateStats();
  }

  void _initializeGrid() {
    grid = MinesGrid(onTileRevealed: _onTileRevealed, gameSize: size);
    add(grid);
  }

  void _initializeUI() {
    // Stats display - position based on percentage
    final statsY = size.y * MinesConstants.statsDisplayY;

    // Diamonds found
    diamondsText = TextComponent(
      text:
          '${MinesConstants.diamondsFoundLabel}: 0/${MinesConstants.diamondCount}',
      position: Vector2(size.x * 0.5, statsY),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: MinesConstants.textColorPrimary,
          fontSize: MinesConstants.statsTextSize,
          fontWeight: FontWeight.w300,
          letterSpacing: MinesConstants.statsLetterSpacing,
        ),
      ),
    );
    add(diamondsText);

    // Multiplier
    multiplierText = TextComponent(
      text: MinesConstants.formatMultiplier(1.0),
      position: Vector2(size.x * 0.5, statsY + 30),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: MinesConstants.textColorSecondary,
          fontSize: MinesConstants.statsTextSize,
          fontWeight: FontWeight.bold,
          letterSpacing: MinesConstants.statsLetterSpacing,
        ),
      ),
    );
    add(multiplierText);

    // Potential win
    potentialWinText = TextComponent(
      text: MinesConstants.formatTime(betAmount),
      position: Vector2(size.x * 0.5, statsY + 70),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: MinesConstants.winColor,
          fontSize: MinesConstants.bigNumberTextSize,
          fontWeight: FontWeight.w100,
          letterSpacing: 2,
        ),
      ),
    );
    add(potentialWinText);

    // Instruction text
    instructionText = TextComponent(
      text: MinesConstants.selectTilesInstruction,
      position: Vector2(size.x * 0.5, size.y * 0.78),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: MinesConstants.textColorSecondary.withOpacity(0.6),
          fontSize: 12,
          fontWeight: FontWeight.w300,
          letterSpacing: 2,
        ),
      ),
    );
    add(instructionText);
  }

  void _onTileRevealed(bool hitBomb, int totalDiamondsFound) {
    diamondsFound = totalDiamondsFound;

    if (hitBomb) {
      // Hit bomb - lose
      _handleGameOver(false);
    } else {
      // Found diamond - update stats
      _updateStats();

      // Check if all diamonds found
      if (diamondsFound >= MinesConstants.diamondCount) {
        _handleGameOver(true);
      }
    }
  }

  void _updateStats() {
    // Update text components
    diamondsText.text =
        '${MinesConstants.diamondsFoundLabel}: $diamondsFound/${MinesConstants.diamondCount}';

    final multiplier = MinesConstants.calculateMultiplier(diamondsFound);
    multiplierText.text = MinesConstants.formatMultiplier(multiplier);

    final potentialWin = MinesConstants.calculatePotentialWin(
      betAmount,
      diamondsFound,
    );
    potentialWinText.text = MinesConstants.formatTime(potentialWin);

    // Emit stats update
    _statsController.add({
      'diamondsFound': diamondsFound,
      'multiplier': multiplier,
      'potentialWin': potentialWin,
    });
  }

  void _handleGameOver(bool won) {
    isGameOver = true;
    hasWon = won;

    // Update instruction text
    instructionText.text = won
        ? MinesConstants.allClearMessage
        : MinesConstants.loserMessage;

    instructionText.textRenderer = TextPaint(
      style: TextStyle(
        color: won ? MinesConstants.winColor : MinesConstants.loseColor,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 4,
        shadows: [
          Shadow(
            color: (won ? MinesConstants.winColor : MinesConstants.loseColor)
                .withOpacity(MinesConstants.glowOpacity),
            offset: Offset.zero,
            blurRadius: MinesConstants.glowBlurRadius,
          ),
        ],
      ),
    );

    // Calculate time change
    int timeChange;
    if (won) {
      // Won - get potential winnings
      timeChange = MinesConstants.calculateProfit(betAmount, diamondsFound);
    } else {
      // Lost - lose bet amount
      timeChange = -betAmount;
    }

    // Create result
    final result = GameResult(
      won: won,
      timeChange: timeChange,
      gameName: 'Mines',
      resultMessage: won
          ? '${MinesConstants.winnerMessage} Found all diamonds!'
          : '${MinesConstants.loserMessage} Hit a bomb!',
    );

    // Wait before returning result
    Future.delayed(const Duration(seconds: 2), () {
      onGameComplete?.call(result);
    });
  }

  void cashOut() {
    if (isGameOver || diamondsFound == 0) return;

    // Cash out current winnings
    _handleGameOver(true);
  }

  void resetGame() {
    if (!isGameOver) return;

    // Reset state
    isGameOver = false;
    hasWon = false;
    diamondsFound = 0;

    // Reset grid
    grid.reset();

    // Reset UI
    instructionText.text = MinesConstants.selectTilesInstruction;
    instructionText.textRenderer = TextPaint(
      style: TextStyle(
        color: MinesConstants.textColorSecondary.withOpacity(0.6),
        fontSize: 12,
        fontWeight: FontWeight.w300,
        letterSpacing: 2,
      ),
    );

    _updateStats();
  }

  @override
  void onRemove() {
    _statsController.close();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    // Pure black background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = MinesConstants.backgroundColor,
    );

    // Subtle grid texture
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x <= size.x; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    }
    for (double y = 0; y <= size.y; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);
    }

    // Top ambient red glow
    canvas.drawCircle(
      Offset(size.x * 0.5, -40),
      size.x * 0.6,
      Paint()
        ..color = const Color(0xFFEF4444).withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );

    // Subtle vignette
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(0.2),
        Colors.black.withOpacity(0.5),
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..shader = vignette.createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );

    super.render(canvas);
  }
}
