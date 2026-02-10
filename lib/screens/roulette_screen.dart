import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit/game_result.dart';
import '../games/roulette_game.dart';
import '../games/roulette_constants.dart';
import 'dart:ui' show FontFeature;

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen>
    with TickerProviderStateMixin {
  late RouletteGame _game;
  int remainingTime = 0;
  bool isLoaded = false;
  BetType? selectedBet;

  // Animation controller for selected border
  late AnimationController _borderController;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize border animation
    _borderController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _borderAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _borderController, curve: Curves.easeInOut),
    );

    _loadRemainingTime();
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  Future<void> _loadRemainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    final remaining = prefs.getInt('remaining_seconds') ?? 0;

    setState(() {
      remainingTime = remaining;
      isLoaded = true;
    });

    _game = RouletteGame(
      betAmount: remainingTime,
      onGameComplete: _onGameComplete,
      onBetChanged: _onBetChanged,
    );
  }

  /// Called when bet selection changes
  void _onBetChanged(BetType? newBet) {
    setState(() {
      selectedBet = newBet;
    });
  }

  /// Called when a game round is complete
  void _onGameComplete(GameResult result) {
    // Pop back to previous screen with the result
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar - only game name and bet amount
            _buildTopBar(),

            // Game canvas (roulette wheel)
            Expanded(flex: 3, child: GameWidget(game: _game)),

            // Messages area (between wheel and buttons)
            _buildMessagesArea(),

            // Bottom controls
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final minutes = remainingTime ~/ 60;
    final seconds = remainingTime % 60;
    final timeString = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'ROULETTE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'BETTING: $timeString',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF22C55E), // Green
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: StreamBuilder<String>(
        stream: _game.messageStream,
        initialData: '',
        builder: (context, snapshot) {
          return Text(
            snapshot.data ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color: Colors.black, // Dark background for controls
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bet buttons grid
          _buildBetButtons(),
          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Clear bet
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _game.clearBet();
                    setState(() {
                      selectedBet = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('CLEAR'),
                ),
              ),
              const SizedBox(width: 16),

              // Spin
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _game.spin(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'SPIN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBetButtons() {
    return Column(
      children: [
        Row(
          children: [
            // Red (Visual Red -> Logic White)
            _buildBetButton(BetType.white(), const Color(0xFFEF4444)), // Red
            const SizedBox(width: 8),
            // Black
            _buildBetButton(BetType.black(), Colors.black),
            const SizedBox(width: 8),
            // Green (0)
            _buildBetButton(
              BetType.straight(0),
              const Color(0xFF22C55E),
            ), // Green
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            _buildBetButton(BetType.even()),
            const SizedBox(width: 8),
            _buildBetButton(BetType.odd()),
          ],
        ),
        const SizedBox(height: 8),

        // Third row: Low, High
        Row(
          children: [
            _buildBetButton(BetType.low()),
            const SizedBox(width: 8),
            _buildBetButton(BetType.high()),
          ],
        ),
      ],
    );
  }

  Widget _buildBetButton(BetType betType, [Color? color]) {
    final isSelected = selectedBet?.name == betType.name;

    // Default to secondary styled button if no color provided (for even/odd/high/low)
    final bool isColored = color != null;
    final backgroundColor =
        color ?? const Color(0xFF27272A); // muted/secondary color
    final textColor = Colors.white;

    return Expanded(
      child: AnimatedBuilder(
        animation: _borderAnimation,
        builder: (context, child) {
          final borderColor = isSelected
              ? const Color(0xFF22C55E).withOpacity(_borderAnimation.value)
              : Colors.transparent;

          return ElevatedButton(
            onPressed: () => _game.placeBet(betType),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: isSelected ? 8 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: borderColor, width: isSelected ? 2 : 0),
              ),
              shadowColor: isSelected
                  ? const Color(
                      0xFF22C55E,
                    ).withOpacity(_borderAnimation.value * 0.5)
                  : null,
            ),
            child: Text(
              betType.name.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }
}
