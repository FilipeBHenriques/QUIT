import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit/game_result.dart';
import '../games/roulette_game.dart';
import '../games/roulette_constants.dart';

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
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'ROULETTE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'BETTING: $timeString',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.greenAccent.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
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
    // This will show the game messages (from the RouletteGame)
    // The game itself will render text components on the canvas
    // This is just a spacer for layout
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: StreamBuilder<String>(
        stream: _game.messageStream,
        initialData: '',
        builder: (context, snapshot) {
          return Text(
            snapshot.data ?? '',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w300,
              letterSpacing: 4,
              shadows: [
                Shadow(
                  color: Colors.white.withOpacity(0.5),
                  offset: Offset.zero,
                  blurRadius: 20,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
      ),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
            _buildBetButton(BetType.white(), Colors.white),
            const SizedBox(width: 8),
            _buildBetButton(BetType.black(), Colors.black),
            const SizedBox(width: 8),
            _buildBetButton(BetType.straight(0), Colors.green),
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

  Widget _buildBetButton(BetType betType, [Color color = Colors.black]) {
    final isSelected = selectedBet?.name == betType.name;

    // Determine text color based on background
    final bool isWhiteBg = color.value == Colors.white.value;
    final Color textColor = isWhiteBg ? Colors.black : Colors.white;

    return Expanded(
      child: AnimatedBuilder(
        animation: _borderAnimation,
        builder: (context, child) {
          // Animated border opacity
          final borderColor = isSelected
              ? Colors.greenAccent.withOpacity(_borderAnimation.value)
              : Colors.transparent;

          return ElevatedButton(
            onPressed: () => _game.placeBet(betType),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: isSelected ? 8 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: borderColor, width: isSelected ? 3 : 0),
              ),
              shadowColor: isSelected
                  ? Colors.greenAccent.withOpacity(_borderAnimation.value * 0.5)
                  : null,
            ),
            child: Text(
              betType.name.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: textColor,
              ),
            ),
          );
        },
      ),
    );
  }
}
