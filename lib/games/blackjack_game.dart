import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:quit/game_result.dart';

// ============================================================================
// CONSTANTS & CONFIGURATION
// ============================================================================

class GameConstants {
  static const double cardWidth = 80.0;
  static const double cardHeight = 112.0;
  static const double cardRadius = 10.0;

  static const double cardSpacing = 75.0;
  static const double deckXRatio = 0.95;
  static const double deckCenterYRatio = 0.5;

  static const double dealerCardsYRatio = 0.25;
  static const double playerCardsYRatio = 0.80;
  static const double dealerLabelYRatio = 0.05;
  static const double playerLabelYRatio = 0.67;
  static const double dealerScoreYRatio = 0.125;
  static const double playerScoreYRatio = 0.70;

  static const int deckShuffleThreshold = 15;
  static const int dealerStandThreshold = 17;
  static const int blackjackScore = 21;

  static const int cardDealDelay = 300;
  static const int cardDealStagger = 300;
  static const int cardFlipDuration = 400;
  static const int cardMoveDuration = 350;

  static const double spotlightRadius = 180.0;
  static const double shadowBlur = 8.0;
  static const double textGlowBlur = 20.0;
}

class GameText {
  static const String tapToStart = 'TAP TO START';
  static const String newDeck = 'NEW DECK';
  static const String bust = 'BUST';
  static const String blackjack = 'BLACKJACK!';
  static const String youWin = 'YOU WIN';
  static const String dealerWins = 'DEALER WINS';
  static const String push = 'PUSH';
  static const String dealer = 'DEALER';
  static const String player = 'PLAYER';
  static const String quit = 'Q';
}

class CardDeck {
  static const List<String> suits = ['♠', '♥', '♦', '♣'];
  static const List<String> values = [
    'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K',
  ];

  static const int totalCards = 52;

  static bool isRedSuit(String suit) => suit == '♥' || suit == '♦';

  static int getCardValue(String value) {
    if (value == 'A') return 11;
    if (['J', 'Q', 'K'].contains(value)) return 10;
    return int.parse(value);
  }
}

// ============================================================================
// MAIN GAME CLASS
// ============================================================================

class BlackjackGame extends FlameGame with TapCallbacks {
  final Function(GameResult)? onGameComplete;
  final int betAmount;

  BlackjackGame({this.onGameComplete, required this.betAmount});

  final List<PlayingCard> dealerCards = [];
  final List<PlayingCard> playerCards = [];
  final List<PlayingCard> deck = [];

  bool gameStarted = false;
  bool playerTurn = true;

  late TextComponent messageText;
  late TextComponent playerScoreText;
  late TextComponent dealerScoreText;
  late TextComponent dealerLabelText;
  late TextComponent playerLabelText;
  late TextComponent deckCountText;

  final List<Spotlight> spotlights = [];

  Vector2 get deckPosition =>
      Vector2(GameConstants.deckXRatio, size.y * GameConstants.deckCenterYRatio);

  Vector2 get dealerCardStart =>
      Vector2(size.x / 2 - 140, size.y * GameConstants.dealerCardsYRatio);

  Vector2 get playerCardStart =>
      Vector2(size.x / 2 - 140, size.y * GameConstants.playerCardsYRatio);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _initializeSpotlights();
    _initializeUI();
  }

  void _initializeSpotlights() {
    final positions = [
      Vector2(size.x * 0.3, 100),
      Vector2(size.x * 0.7, 100),
      Vector2(size.x * 0.3, size.y - 100),
      Vector2(size.x * 0.7, size.y - 100),
    ];
    for (var position in positions) {
      final spotlight = Spotlight(position, GameConstants.spotlightRadius);
      spotlights.add(spotlight);
      add(spotlight);
    }
  }

  void _initializeUI() {
    dealerLabelText = _createLabel(
      GameText.dealer,
      Vector2(size.x / 2, size.y * GameConstants.dealerLabelYRatio),
    );
    add(dealerLabelText);

    playerLabelText = _createLabel(
      GameText.player,
      Vector2(size.x / 2, size.y * GameConstants.playerLabelYRatio),
    );
    add(playerLabelText);

    dealerScoreText = _createScoreText(
      Vector2(size.x / 2, size.y * GameConstants.dealerScoreYRatio),
    );
    add(dealerScoreText);

    playerScoreText = _createScoreText(
      Vector2(size.x / 2, size.y * GameConstants.playerScoreYRatio),
    );
    add(playerScoreText);

    deckCountText = TextComponent(
      text: '52',
      position: Vector2(30, size.y / 2 - 35),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF3D4558),
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
    add(deckCountText);

    messageText = TextComponent(
      text: GameText.tapToStart,
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFF0F2F8),
          fontSize: 22,
          fontWeight: FontWeight.w300,
          letterSpacing: 7,
          shadows: [
            Shadow(
              color: Color(0x8D9B5CFF), // violet ~55% opacity
              offset: Offset.zero,
              blurRadius: GameConstants.textGlowBlur,
            ),
          ],
        ),
      ),
    );
    add(messageText);
  }

  TextComponent _createLabel(String text, Vector2 position) {
    return TextComponent(
      text: text,
      position: position,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF3D4558),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 4,
        ),
      ),
    );
  }

  TextComponent _createScoreText(Vector2 position) {
    return TextComponent(
      text: '0',
      position: position,
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFF0F2F8),
          fontSize: 40,
          fontWeight: FontWeight.w200,
          letterSpacing: 2,
        ),
      ),
    );
  }

  List<PlayingCard> _createDeck() {
    final newDeck = <PlayingCard>[];
    for (var suit in CardDeck.suits) {
      for (var value in CardDeck.values) {
        newDeck.add(
          PlayingCard(suit: suit, value: value, deckPosition: deckPosition),
        );
      }
    }
    return newDeck;
  }

  void _reshuffleIfNeeded() {
    if (deck.isEmpty || deck.length < GameConstants.deckShuffleThreshold) {
      deck.clear();
      deck.addAll(_createDeck());
      deck.shuffle();
      _showTemporaryMessage(GameText.newDeck, 1500);
      _updateDeckCounter();
    }
  }

  void startNewGame() {
    _clearPreviousHand();
    _reshuffleIfNeeded();
    _dealInitialCards();
    gameStarted = true;
    playerTurn = true;
    _setMessage('');
  }

  void _clearPreviousHand() {
    for (var card in [...dealerCards, ...playerCards]) {
      card.removeFromParent();
    }
    dealerCards.clear();
    playerCards.clear();
  }

  void _dealInitialCards() {
    final delays = [200, 500, 800, 1100];
    Future.delayed(Duration(milliseconds: delays[0]), () {
      _dealCard(playerCards, playerCardStart);
    });
    Future.delayed(Duration(milliseconds: delays[1]), () {
      _dealCard(dealerCards, dealerCardStart);
    });
    Future.delayed(Duration(milliseconds: delays[2]), () {
      _dealCard(playerCards, playerCardStart);
    });
    Future.delayed(Duration(milliseconds: delays[3]), () {
      _dealCard(dealerCards, dealerCardStart, faceDown: true);
      Future.delayed(const Duration(milliseconds: 400), _checkBlackjack);
    });
  }

  void _dealCard(
    List<PlayingCard> hand,
    Vector2 startPos, {
    bool faceDown = false,
  }) {
    if (deck.isEmpty) return;
    final card = deck.removeAt(0);
    final targetPos =
        startPos + Vector2(hand.length * GameConstants.cardSpacing, 0);
    card.position = deckPosition.clone();
    card.isFaceDown = faceDown;
    card.animateToPosition(targetPos);
    hand.add(card);
    add(card);
    _updateDeckCounter();
    Future.delayed(
      const Duration(milliseconds: GameConstants.cardDealDelay),
      _updateScores,
    );
  }

  void hit() {
    if (!gameStarted || !playerTurn) return;
    _dealCard(playerCards, playerCardStart);
    Future.delayed(const Duration(milliseconds: 500), () {
      final score = _calculateScore(playerCards);
      if (score > GameConstants.blackjackScore) _endGame(GameText.bust);
    });
  }

  void stand() {
    if (!gameStarted || !playerTurn) return;
    playerTurn = false;
    _revealDealerCard();
    Future.delayed(const Duration(milliseconds: 800), _dealerPlay);
  }

  void _revealDealerCard() {
    for (var card in dealerCards) {
      if (card.isFaceDown) card.flipCard();
    }
    Future.delayed(const Duration(milliseconds: 500), _updateScores);
  }

  void _dealerPlay() {
    final dealerScore = _calculateScore(dealerCards);
    if (dealerScore < GameConstants.dealerStandThreshold) {
      _dealCard(dealerCards, dealerCardStart);
      Future.delayed(const Duration(milliseconds: 800), _dealerPlay);
    } else {
      Future.delayed(const Duration(milliseconds: 600), _determineWinner);
    }
  }

  int _calculateScore(List<PlayingCard> hand) {
    int score = 0;
    int aces = 0;
    for (var card in hand) {
      if (card.isFaceDown) continue;
      if (card.value == 'A') aces++;
      score += CardDeck.getCardValue(card.value);
    }
    while (score > GameConstants.blackjackScore && aces > 0) {
      score -= 10;
      aces--;
    }
    return score;
  }

  void _checkBlackjack() {
    if (_calculateScore(playerCards) == GameConstants.blackjackScore) {
      _endGame(GameText.blackjack);
    }
  }

  void _determineWinner() {
    final playerScore = _calculateScore(playerCards);
    final dealerScore = _calculateScore(dealerCards);
    if (dealerScore > GameConstants.blackjackScore) {
      _endGame(GameText.youWin);
    } else if (playerScore > dealerScore) {
      _endGame(GameText.youWin);
    } else if (dealerScore > playerScore) {
      _endGame(GameText.dealerWins);
    } else {
      _endGame(GameText.push);
    }
  }

  void _endGame(String message) {
    gameStarted = false;
    playerTurn = false;
    _setMessage(message);
    final won = message == GameText.youWin || message == GameText.blackjack;
    final push = message == GameText.push;
    final timeChange = push ? 0 : (won ? betAmount : -betAmount);
    final result = GameResult(
      won: won || push,
      timeChange: timeChange,
      gameName: 'Blackjack',
      resultMessage: message,
    );
    Future.delayed(const Duration(seconds: 2), () => onGameComplete?.call(result));
  }

  void _setMessage(String text) => messageText.text = text;

  void _showTemporaryMessage(String text, int durationMs) {
    _setMessage(text);
    Future.delayed(Duration(milliseconds: durationMs), () => _setMessage(''));
  }

  void _updateScores() {
    playerScoreText.text = '${_calculateScore(playerCards)}';
    final hasFaceDown = dealerCards.any((c) => c.isFaceDown);
    if (hasFaceDown && dealerCards.length > 1) {
      dealerScoreText.text = '?';
    } else {
      dealerScoreText.text = '${_calculateScore(dealerCards)}';
    }
  }

  void _updateDeckCounter() {
    deckCountText.text = '${deck.length}';
    final isLow = deck.length < GameConstants.deckShuffleThreshold;
    deckCountText.textRenderer = TextPaint(
      style: TextStyle(
        color: isLow
            ? const Color(0xFFFFAB00).withValues(alpha: 0.7)
            : const Color(0xFF3D4558),
        fontSize: 11,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!gameStarted) startNewGame();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = const Color(0xFF020408),
    );

    // Dot grid
    final gridPaint = Paint()
      ..color = const Color(0xFF14161E).withValues(alpha: 0.6)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x <= size.x; x += step) {
      for (double y = 0; y <= size.y; y += step) {
        canvas.drawCircle(Offset(x, y), 0.8, gridPaint);
      }
    }

    // Violet top glow
    canvas.drawCircle(
      Offset(size.x * 0.5, -40),
      size.x * 0.55,
      Paint()
        ..color = const Color(0xFF9B5CFF).withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );

    // Mint bottom glow
    canvas.drawCircle(
      Offset(size.x * 0.5, size.y + 40),
      size.x * 0.40,
      Paint()
        ..color = const Color(0xFF00D68F).withValues(alpha: 0.05)
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
      stops: const [0.0, 0.65, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..shader = vignette.createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );

    super.render(canvas);
  }
}

// ============================================================================
// SPOTLIGHT COMPONENT
// ============================================================================

class Spotlight extends PositionComponent {
  final double radius;
  double _pulse = 0.0;

  Spotlight(Vector2 position, this.radius) : super(position: position);

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt;
  }

  @override
  void render(Canvas canvas) {
    final pulseFactor = 0.6 + (sin(_pulse * 1.8) * 0.4);
    final gradient = RadialGradient(
      colors: [
        Color.fromRGBO(155, 92, 255, 0.10 * pulseFactor),
        Color.fromRGBO(155, 92, 255, 0.03 * pulseFactor),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: Offset.zero, radius: radius),
        ),
    );
  }
}

// ============================================================================
// PLAYING CARD COMPONENT
// ============================================================================

class PlayingCard extends PositionComponent {
  final String suit;
  final String value;
  final Vector2 deckPosition;
  bool isFaceDown = false;

  double _flipProgress = 0.0;
  bool _isFlipping = false;

  PlayingCard({
    required this.suit,
    required this.value,
    required this.deckPosition,
  }) : super(
         size: Vector2(GameConstants.cardWidth, GameConstants.cardHeight),
         anchor: Anchor.center,
       );

  void animateToPosition(Vector2 target) {
    final duration = GameConstants.cardMoveDuration / 1000.0;
    final startPos = position.clone();
    double elapsed = 0;

    void animate(double dt) {
      elapsed += dt;
      final progress = (elapsed / duration).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(progress);
      position = Vector2(
        startPos.x + (target.x - startPos.x) * eased,
        startPos.y + (target.y - startPos.y) * eased,
      );
      if (progress < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), () => animate(0.016));
      }
    }

    animate(0);
  }

  void flipCard() {
    _isFlipping = true;
    final duration = GameConstants.cardFlipDuration / 1000.0;
    double elapsed = 0;

    void animate(double dt) {
      elapsed += dt;
      _flipProgress = (elapsed / duration).clamp(0.0, 1.0);
      if (_flipProgress >= 0.5 && isFaceDown) isFaceDown = false;
      if (_flipProgress < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), () => animate(0.016));
      } else {
        _isFlipping = false;
        _flipProgress = 0.0;
      }
    }

    animate(0);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    _applyFlipTransform(canvas);
    _renderShadow(canvas);
    _renderCardBackground(canvas);
    if (_shouldShowBack()) {
      _renderCardBack(canvas);
    } else {
      _renderCardFace(canvas);
    }
    canvas.restore();
  }

  void _applyFlipTransform(Canvas canvas) {
    if (_isFlipping) {
      final scaleX = (1 - (_flipProgress * 2 - 1).abs());
      canvas.translate(size.x / 2, 0);
      canvas.scale(scaleX, 1.0);
      canvas.translate(-size.x / 2, 0);
    }
  }

  void _renderShadow(Canvas canvas) {
    canvas.drawPath(
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 6, size.x, size.y),
            Radius.circular(GameConstants.cardRadius),
          ),
        ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, GameConstants.shadowBlur),
    );
  }

  void _renderCardBackground(Canvas canvas) {
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Radius.circular(GameConstants.cardRadius),
    );
    canvas.drawRRect(
      cardRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF5F5F8)],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    );
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = const Color(0xFFD8DAE0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  bool _shouldShowBack() {
    return (isFaceDown && !_isFlipping) || (_isFlipping && _flipProgress < 0.5);
  }

  void _renderCardBack(Canvas canvas) {
    final backRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3, 3, size.x - 6, size.y - 6),
      Radius.circular(GameConstants.cardRadius - 2),
    );
    canvas.drawRRect(
      backRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0C14), Color(0xFF060810)],
        ).createShader(Rect.fromLTWH(3, 3, size.x - 6, size.y - 6)),
    );
    _renderBackGrid(canvas);
    _renderBackLogo(canvas);
  }

  void _renderBackGrid(Canvas canvas) {
    // Cyan grid
    final gridPaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.08)
      ..strokeWidth = 0.5;
    const step = 10.0;
    for (double x = 6; x <= size.x - 6; x += step) {
      canvas.drawLine(Offset(x, 6), Offset(x, size.y - 6), gridPaint);
    }
    for (double y = 6; y <= size.y - 6; y += step) {
      canvas.drawLine(Offset(6, y), Offset(size.x - 6, y), gridPaint);
    }

    // Nested frames
    final framePaint = Paint()
      ..color = const Color(0xFF00F0FF).withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 0; i < 3; i++) {
      final inset = 6.0 + (i * 5.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inset, inset, size.x - inset * 2, size.y - inset * 2),
          const Radius.circular(4),
        ),
        framePaint,
      );
    }

    // Cyan stripe
    canvas.drawLine(
      Offset(size.x * 0.25, size.y * 0.88),
      Offset(size.x * 0.75, size.y * 0.88),
      Paint()
        ..color = const Color(0xFF00F0FF).withValues(alpha: 0.55)
        ..strokeWidth = 1.0,
    );
  }

  void _renderBackLogo(Canvas canvas) {
    final logoText = TextPainter(
      text: const TextSpan(
        text: 'Q',
        style: TextStyle(
          color: Color(0xFF00F0FF),
          fontSize: 30,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Color(0xFF00F0FF),
              offset: Offset.zero,
              blurRadius: 12,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    logoText.paint(
      canvas,
      Offset(size.x / 2 - logoText.width / 2, size.y / 2 - logoText.height / 2),
    );
  }

  void _renderCardFace(Canvas canvas) {
    final isRed = CardDeck.isRedSuit(suit);
    final cardColor =
        isRed ? const Color(0xFFDC2626) : const Color(0xFF0F1018);
    _renderCorner(canvas, cardColor);
    _renderRotatedCorner(canvas, cardColor);
    _renderCenterSuit(canvas, cardColor);
  }

  void _renderCorner(Canvas canvas, Color color) {
    final valueText = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final suitText = TextPainter(
      text: TextSpan(
        text: suit,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    valueText.paint(canvas, const Offset(8, 8));
    suitText.paint(canvas, Offset(8, 8 + valueText.height + 2));
  }

  void _renderRotatedCorner(Canvas canvas, Color color) {
    canvas.save();
    canvas.translate(size.x, size.y);
    canvas.rotate(pi);
    _renderCorner(canvas, color);
    canvas.restore();
  }

  void _renderCenterSuit(Canvas canvas, Color color) {
    final centerSuit = TextPainter(
      text: TextSpan(
        text: suit,
        style: TextStyle(
          color: color.withValues(alpha: 0.10),
          fontSize: 68,
          fontWeight: FontWeight.w100,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    centerSuit.paint(
      canvas,
      Offset(
        size.x / 2 - centerSuit.width / 2,
        size.y / 2 - centerSuit.height / 2,
      ),
    );
  }
}
