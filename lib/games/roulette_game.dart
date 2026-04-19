import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:quit/game_result.dart';

import 'roulette_constants.dart';
import 'roulette_wheel.dart';

// ============================================================================
// ROULETTE GAME
// ============================================================================

class RouletteGame extends FlameGame {
  final Function(GameResult)? onGameComplete;
  final Function(BetType?)? onBetChanged;
  final Function(int number, bool won)? onResultReady;
  final int betAmount;

  RouletteGame({
    this.onGameComplete,
    this.onBetChanged,
    this.onResultReady,
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

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _initializeWheel();
  }

  void _initializeWheel() {
    // Center the wheel vertically in the canvas (no overlapping text)
    final wheelCenter = Vector2(size.x * 0.5, size.y * 0.52);

    wheel = RouletteWheel(
      position: wheelCenter,
      onSpinComplete: _onSpinComplete,
    );
    add(wheel);
  }

  // ============================================================================
  // BETTING
  // ============================================================================

  void placeBet(BetType betType) {
    if (isSpinning) return;

    currentBet = betType;
    lastWinningNumber = null;
    resultMessage = '';

    onBetChanged?.call(betType);
    _setMessage('');
  }

  void clearBet() {
    if (isSpinning) return;

    currentBet = null;
    lastWinningNumber = null;
    resultMessage = '';

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

    final winningNumber = Random().nextInt(RouletteConstants.totalNumbers);
    lastWinningNumber = winningNumber;

    wheel.spin(winningNumber);
  }

  void _onSpinComplete() {
    if (lastWinningNumber == null) return;

    final won = currentBet!.numbers.contains(lastWinningNumber);

    final int timeChange;
    if (won) {
      timeChange = betAmount * currentBet!.payout;
      resultMessage = '${RouletteText.winner} ${currentBet!.name}!';
    } else {
      timeChange = -betAmount;
      resultMessage = 'LOSE — ${currentBet!.name}';
    }

    _setMessage(resultMessage);
    isSpinning = false;

    // Notify Flutter UI to display the winning number
    onResultReady?.call(lastWinningNumber!, won);

    final result = GameResult(
      won: won,
      betAmount: betAmount,
      timeChange: timeChange,
      gameName: 'Roulette',
      resultMessage: resultMessage,
    );

    Future.delayed(const Duration(seconds: 2), () {
      onGameComplete?.call(result);
    });
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
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Colors.black,
    );

    // Subtle dot grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 0.5;
    const step = 32.0;
    for (double x = 0; x <= size.x; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    }
    for (double y = 0; y <= size.y; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);
    }

    // Top ambient violet glow
    canvas.drawCircle(
      Offset(size.x * 0.5, -20),
      size.x * 0.55,
      Paint()
        ..color = const Color(0xFF9B5CFF).withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );

    // Vignette
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        Colors.transparent,
        Colors.black.withValues(alpha: 0.25),
        Colors.black.withValues(alpha: 0.55),
      ],
      stops: const [0.0, 0.7, 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..shader =
            vignette.createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );

    super.render(canvas);
  }
}
