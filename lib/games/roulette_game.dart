import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'roulette_constants.dart';
import 'roulette_wheel.dart';

// ============================================================================
// SIMPLIFIED ROULETTE GAME - ONE BET PER SPIN
// ============================================================================

class RouletteGame extends FlameGame {
  // Game state
  BetType? currentBet;
  bool isSpinning = false;
  int? lastWinningNumber;
  String resultMessage = '';

  // Components
  late RouletteWheel wheel;
  late TextComponent messageText;
  late TextComponent winningNumberText;
  late TextComponent betText;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _initializeWheel();
    _initializeUI();
  }

  void _initializeWheel() {
    final wheelCenter = Vector2(size.x / 2, 220);

    wheel = RouletteWheel(
      position: wheelCenter,
      onSpinComplete: _onSpinComplete,
    );
    add(wheel);
  }

  void _initializeUI() {
    // Current bet display
    betText = TextComponent(
      text: 'SELECT A BET',
      position: Vector2(size.x / 2, 50),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w300,
          letterSpacing: 3,
        ),
      ),
    );
    add(betText);

    // Message text
    messageText = TextComponent(
      text: RouletteText.placeBets,
      position: Vector2(size.x / 2, 450),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w300,
          letterSpacing: 4,
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(0.5),
              offset: Offset.zero,
              blurRadius: RouletteConstants.glowBlur,
            ),
          ],
        ),
      ),
    );
    add(messageText);

    // Winning number display
    winningNumberText = TextComponent(
      text: '',
      position: Vector2(size.x / 2, 90),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 64,
          fontWeight: FontWeight.w100,
          letterSpacing: 4,
        ),
      ),
    );
    add(winningNumberText);
  }

  // ============================================================================
  // BETTING
  // ============================================================================

  void placeBet(BetType betType) {
    if (isSpinning) return;

    currentBet = betType;
    lastWinningNumber = null;
    resultMessage = '';

    _updateUI();
  }

  void clearBet() {
    if (isSpinning) return;

    currentBet = null;
    lastWinningNumber = null;
    resultMessage = '';

    _updateUI();
    winningNumberText.text = '';
  }

  // ============================================================================
  // SPINNING
  // ============================================================================

  void spin() {
    if (isSpinning) return;
    if (currentBet == null) {
      _setMessage(RouletteText.noBets);
      return;
    }

    isSpinning = true;
    _setMessage(RouletteText.spinning);
    winningNumberText.text = '';

    // Generate random winning number
    final winningNumber = Random().nextInt(RouletteConstants.totalNumbers);
    lastWinningNumber = winningNumber;

    // Spin wheel
    wheel.spin(winningNumber);
  }

  void _onSpinComplete() {
    if (lastWinningNumber == null) return;

    // Show winning number with color
    _showWinningNumber(lastWinningNumber!);

    // Check if bet won
    final won = currentBet!.numbers.contains(lastWinningNumber);

    if (won) {
      resultMessage = '${RouletteText.winner} ${currentBet!.name}!';
      _setMessage(resultMessage);
    } else {
      resultMessage = 'LOSE - ${currentBet!.name}';
      _setMessage(resultMessage);
    }

    isSpinning = false;
  }

  void _showWinningNumber(int number) {
    // Update text
    winningNumberText.text = '$number';

    // Update color based on number
    final color = RouletteNumbers.getNumberColor(number);
    final isZero = number == 0;

    winningNumberText.textRenderer = TextPaint(
      style: TextStyle(
        color: isZero ? Colors.greenAccent : color,
        fontSize: 64,
        fontWeight: FontWeight.w100,
        letterSpacing: 4,
        shadows: isZero
            ? [
                Shadow(
                  color: Colors.greenAccent.withOpacity(0.8),
                  offset: Offset.zero,
                  blurRadius: 30,
                ),
              ]
            : null,
      ),
    );
  }

  // ============================================================================
  // UI UPDATES
  // ============================================================================

  void _updateUI() {
    if (currentBet == null) {
      betText.text = 'SELECT A BET';
      betText.textRenderer = TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w300,
          letterSpacing: 3,
        ),
      );
    } else {
      betText.text = 'BET: ${currentBet!.name.toUpperCase()}';
      betText.textRenderer = TextPaint(
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
      );
    }
  }

  void _setMessage(String text) {
    messageText.text = text;
  }

  // ============================================================================
  // RENDERING
  // ============================================================================

  @override
  void render(Canvas canvas) {
    // Pure black background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Colors.black,
    );

    // Vignette
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Colors.transparent,
        Colors.black.withOpacity(0.3),
        Colors.black.withOpacity(0.6),
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
