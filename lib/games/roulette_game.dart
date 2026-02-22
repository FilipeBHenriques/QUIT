import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:quit/game_result.dart';

import 'roulette_constants.dart';
import 'roulette_wheel.dart';

// ============================================================================
// SIMPLIFIED ROULETTE GAME - ONE BET PER SPIN
// ============================================================================

class RouletteGame extends FlameGame {
  // Callback when game is complete
  final Function(GameResult)? onGameComplete;

  // Callback when bet changes
  final Function(BetType?)? onBetChanged;

  // Bet amount (full time remaining)
  final int betAmount;

  RouletteGame({
    this.onGameComplete,
    this.onBetChanged,
    required this.betAmount,
  });

  // Game state
  BetType? currentBet;
  bool isSpinning = false;
  int? lastWinningNumber;
  String resultMessage = '';

  // Stream for messages (to show in UI)
  final _messageController = StreamController<String>.broadcast();
  Stream<String> get messageStream => _messageController.stream;

  // Components
  late RouletteWheel wheel;
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
    final wheelCenter = Vector2(size.x * 0.5, size.y * 0.35); // 50% x, 35% y

    wheel = RouletteWheel(
      position: wheelCenter,
      onSpinComplete: _onSpinComplete,
    );
    add(wheel);
  }

  void _initializeUI() {
    // Current bet display - top
    betText = TextComponent(
      text: 'SELECT A BET',
      position: Vector2(size.x * 0.5, size.y * 0.80), // 50% x, 8% y
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

    // Winning number display - center
    winningNumberText = TextComponent(
      text: '',
      position: Vector2(size.x * 0.5, size.y * 0.70), // Center
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

    // Notify UI of bet change
    onBetChanged?.call(betType);
    _setMessage('');
  }

  void clearBet() {
    if (isSpinning) return;

    currentBet = null;
    lastWinningNumber = null;
    resultMessage = '';

    _updateUI();
    winningNumberText.text = '';

    // Notify UI of bet cleared
    onBetChanged?.call(null);
    _setMessage('');
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

    // Calculate time change based on bet amount
    final int timeChange;
    if (won) {
      // Win: Get back bet + payout based on bet type odds
      final payout = (betAmount * currentBet!.payout).toInt();
      timeChange = payout; // Net gain
      resultMessage = '${RouletteText.winner} ${currentBet!.name}!';
    } else {
      // Lose: Lose the bet amount
      timeChange = -betAmount;
      resultMessage = 'LOSE - ${currentBet!.name}';
    }

    _setMessage(resultMessage);
    isSpinning = false;

    // Create game result and send to callback
    final result = GameResult(
      won: won,
      timeChange: timeChange,
      gameName: 'Roulette',
      resultMessage: resultMessage,
    );

    // Wait a bit before returning result so user can see the outcome
    Future.delayed(const Duration(seconds: 2), () {
      onGameComplete?.call(result);
    });
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
    }
  }

  void _setMessage(String text) {
    _messageController.add(text);
  }

  @override
  void onRemove() {
    _messageController.close();
    super.onRemove();
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

    // Subtle grid texture
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
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
      Offset(size.x * 0.5, -35),
      size.x * 0.58,
      Paint()
        ..color = const Color(0xFFEF4444).withOpacity(0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
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
