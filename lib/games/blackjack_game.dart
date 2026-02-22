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
  // Card dimensions (could even make these responsive too)
  static const double cardWidth = 80.0;
  static const double cardHeight = 112.0;
  static const double cardRadius = 8.0;

  // Layout - all as ratios of screen size
  static const double cardSpacing = 75.0; // or make this ratio-based too
  static const double deckXRatio = 0.95; // 5% from left edge
  static const double deckCenterYRatio = 0.5; // 50% down

  // Positioning as ratios (0.0 to 1.0)
  static const double dealerCardsYRatio = 0.25; // 20% from top
  static const double playerCardsYRatio = 0.80; // 75% from top
  static const double dealerLabelYRatio = 0.05; // 8% from top
  static const double playerLabelYRatio = 0.67; // 67% from top
  static const double dealerScoreYRatio = 0.125;
  static const double playerScoreYRatio = 0.70;

  // Game rules
  static const int deckShuffleThreshold = 15; // Reshuffle when < 15 cards
  static const int dealerStandThreshold = 17;
  static const int blackjackScore = 21;

  // Animation timings (milliseconds)
  static const int cardDealDelay = 300;
  static const int cardDealStagger = 300;
  static const int cardFlipDuration = 400;
  static const int cardMoveDuration = 350;

  // Visual effects
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
    'A',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'J',
    'Q',
    'K',
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
  // Callback when game is complete
  final Function(GameResult)? onGameComplete;

  // Bet amount (full time remaining)
  final int betAmount;

  BlackjackGame({this.onGameComplete, required this.betAmount});

  // Game state
  final List<PlayingCard> dealerCards = [];
  final List<PlayingCard> playerCards = [];
  final List<PlayingCard> deck = [];

  bool gameStarted = false;
  bool playerTurn = true;

  // UI Components
  late TextComponent messageText;
  late TextComponent playerScoreText;
  late TextComponent dealerScoreText;
  late TextComponent dealerLabelText;
  late TextComponent playerLabelText;
  late TextComponent deckCountText;

  // Visual effects
  final List<Spotlight> spotlights = [];

  // Computed positions
  Vector2 get deckPosition => Vector2(
    GameConstants.deckXRatio,
    size.y * GameConstants.deckCenterYRatio,
  );

  Vector2 get dealerCardStart =>
      Vector2(size.x / 2 - 140, size.y * GameConstants.dealerCardsYRatio);

  Vector2 get playerCardStart =>
      Vector2(size.x / 2 - 140, size.y * GameConstants.playerCardsYRatio);

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

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
    // Labels
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

    // Scores
    dealerScoreText = _createScoreText(
      Vector2(size.x / 2, size.y * GameConstants.dealerScoreYRatio),
    );
    add(dealerScoreText);

    playerScoreText = _createScoreText(
      Vector2(size.x / 2, size.y * GameConstants.playerScoreYRatio),
    );
    add(playerScoreText);

    // Deck counter
    deckCountText = TextComponent(
      text: '52',
      position: Vector2(30, size.y / 2 - 35),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white.withOpacity(0.3),
          fontSize: 12,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
    add(deckCountText);

    // Message
    messageText = TextComponent(
      text: GameText.tapToStart,
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w300,
          letterSpacing: 6,
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(0.5),
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
        style: TextStyle(
          color: Colors.white.withOpacity(0.4),
          fontSize: 14,
          fontWeight: FontWeight.w300,
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
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w100,
          letterSpacing: 2,
        ),
      ),
    );
  }

  // ============================================================================
  // DECK MANAGEMENT
  // ============================================================================

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
      print('🔄 Shuffling new deck (${deck.length} cards remaining)');
      deck.clear();
      deck.addAll(_createDeck());
      deck.shuffle();

      _showTemporaryMessage(GameText.newDeck, 1500);
      _updateDeckCounter();
    } else {
      print('♠️ Continuing with current deck (${deck.length} cards remaining)');
    }
  }

  // ============================================================================
  // GAME FLOW
  // ============================================================================

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

  // ============================================================================
  // PLAYER ACTIONS
  // ============================================================================

  void hit() {
    if (!gameStarted || !playerTurn) return;

    _dealCard(playerCards, playerCardStart);

    Future.delayed(const Duration(milliseconds: 500), () {
      final score = _calculateScore(playerCards);

      if (score > GameConstants.blackjackScore) {
        _endGame(GameText.bust);
      }
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
      if (card.isFaceDown) {
        card.flipCard();
      }
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

  // ============================================================================
  // SCORING
  // ============================================================================

  int _calculateScore(List<PlayingCard> hand) {
    int score = 0;
    int aces = 0;

    for (var card in hand) {
      if (card.isFaceDown) continue;

      final value = CardDeck.getCardValue(card.value);

      if (card.value == 'A') {
        aces++;
      }

      score += value;
    }

    // Adjust aces from 11 to 1 if needed
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

    // Calculate result and send to callback
    final won = message == GameText.youWin || message == GameText.blackjack;
    final push = message == GameText.push;

    int timeChange;
    if (push) {
      timeChange = 0; // No change on push
    } else if (won) {
      // Win: 2x payout (get bet back + winnings)
      timeChange = betAmount; // Net gain = bet amount
    } else {
      // Loss: Lose bet
      timeChange = -betAmount;
    }

    final result = GameResult(
      won: won || push, // Push counts as "won" for positive display
      timeChange: timeChange,
      gameName: 'Blackjack',
      resultMessage: message,
    );

    // Wait a bit before returning result so user can see the outcome
    Future.delayed(const Duration(seconds: 2), () {
      onGameComplete?.call(result);
    });
  }

  // ============================================================================
  // UI UPDATES
  // ============================================================================

  void _setMessage(String text) {
    messageText.text = text;
  }

  void _showTemporaryMessage(String text, int durationMs) {
    _setMessage(text);
    Future.delayed(Duration(milliseconds: durationMs), () {
      _setMessage('');
    });
  }

  void _updateScores() {
    final playerScore = _calculateScore(playerCards);
    playerScoreText.text = '$playerScore';

    final hasFaceDown = dealerCards.any((card) => card.isFaceDown);

    if (hasFaceDown && dealerCards.length > 1) {
      dealerScoreText.text = '?';
    } else {
      final dealerScore = _calculateScore(dealerCards);
      dealerScoreText.text = '$dealerScore';
    }
  }

  void _updateDeckCounter() {
    deckCountText.text = '${deck.length}';

    final isLow = deck.length < GameConstants.deckShuffleThreshold;
    deckCountText.textRenderer = TextPaint(
      style: TextStyle(
        color: isLow
            ? Colors.orange.withOpacity(0.6)
            : Colors.white.withOpacity(0.3),
        fontSize: 12,
        fontWeight: FontWeight.w300,
      ),
    );
  }

  // ============================================================================
  // INPUT HANDLING
  // ============================================================================

  @override
  void onTapDown(TapDownEvent event) {
    if (!gameStarted) {
      startNewGame();
    }
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
      size.x * 0.6,
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
    final pulseFactor = 0.7 + (sin(_pulse * 2) * 0.3);

    final gradient = RadialGradient(
      colors: [
        Colors.white.withOpacity(0.15 * pulseFactor),
        Colors.white.withOpacity(0.05 * pulseFactor),
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

  // ============================================================================
  // ANIMATIONS
  // ============================================================================

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

      if (_flipProgress >= 0.5 && isFaceDown) {
        isFaceDown = false;
      }

      if (_flipProgress < 1.0) {
        Future.delayed(const Duration(milliseconds: 16), () => animate(0.016));
      } else {
        _isFlipping = false;
        _flipProgress = 0.0;
      }
    }

    animate(0);
  }

  // ============================================================================
  // RENDERING
  // ============================================================================

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
    final shadowPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 4, size.x, size.y),
          Radius.circular(GameConstants.cardRadius),
        ),
      );

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withOpacity(0.38)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          GameConstants.shadowBlur,
        ),
    );
  }

  void _renderCardBackground(Canvas canvas) {
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Radius.circular(GameConstants.cardRadius),
    );

    final faceGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFFFFFFFF), const Color(0xFFF3F4F6)],
    );

    canvas.drawRRect(
      cardRect,
      Paint()
        ..shader = faceGradient.createShader(
          Rect.fromLTWH(0, 0, size.x, size.y),
        ),
    );
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = const Color(0xFFD1D5DB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, size.x - 8, size.y - 8),
        Radius.circular(GameConstants.cardRadius - 2),
      ),
      Paint()
        ..color = const Color(0xFFF9FAFB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
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

    final backGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFF0B0D10), const Color(0xFF1F2937)],
    );

    canvas.drawRRect(
      backRect,
      Paint()
        ..shader = backGradient.createShader(
          Rect.fromLTWH(3, 3, size.x - 6, size.y - 6),
        ),
    );

    _renderBackPattern(canvas);
    _renderBackLogo(canvas);
  }

  void _renderBackPattern(Canvas canvas) {
    final patternPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < 4; i++) {
      final inset = 8.0 + (i * 6.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(inset, inset, size.x - inset * 2, size.y - inset * 2),
          const Radius.circular(4),
        ),
        patternPaint,
      );
    }

    final stripePaint = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.65)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(size.x * 0.2, size.y * 0.86),
      Offset(size.x * 0.8, size.y * 0.86),
      stripePaint,
    );
  }

  void _renderBackLogo(Canvas canvas) {
    final logoText = TextPainter(
      text: TextSpan(
        text: GameText.quit,
        style: TextStyle(
          color: const Color(0xFFEF4444).withOpacity(0.92),
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          shadows: [
            Shadow(
              color: Colors.white.withOpacity(0.22),
              offset: Offset.zero,
              blurRadius: 8,
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
    final cardColor = isRed ? const Color(0xFFDC2626) : Colors.black;

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
          fontSize: 18,
          fontWeight: FontWeight.w700,
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
          fontSize: 15,
          fontWeight: FontWeight.w400,
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
          color: color.withOpacity(0.13),
          fontSize: 72,
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
