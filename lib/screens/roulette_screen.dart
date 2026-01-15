import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../games/roulette_game.dart';
import '../games/roulette_constants.dart';

class RouletteScreen extends StatefulWidget {
  const RouletteScreen({super.key});

  @override
  State<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends State<RouletteScreen> {
  late RouletteGame game;

  @override
  void initState() {
    super.initState();
    game = RouletteGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Flame game canvas
            GameWidget(game: game),

            // Betting UI overlay
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Betting grid
                  _buildBettingGrid(),

                  const SizedBox(height: 16),

                  // Control buttons
                  _buildControls(),
                ],
              ),
            ),

            // Close button
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBettingGrid() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          // Row 1: Black & White
          Row(
            children: [
              Expanded(
                child: _buildBetButton(
                  'BLACK',
                  () => game.placeBet(BetType.black()),
                  Colors.black,
                  Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBetButton(
                  'WHITE',
                  () => game.placeBet(BetType.white()),
                  Colors.white,
                  Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Even & Odd
          Row(
            children: [
              Expanded(
                child: _buildBetButton(
                  'EVEN',
                  () => game.placeBet(BetType.even()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBetButton(
                  'ODD',
                  () => game.placeBet(BetType.odd()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: Low & High
          Row(
            children: [
              Expanded(
                child: _buildBetButton(
                  '1-18',
                  () => game.placeBet(BetType.low()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBetButton(
                  '19-36',
                  () => game.placeBet(BetType.high()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBetButton(
    String label,
    VoidCallback onTap, [
    Color? bgColor,
    Color? textColor,
  ]) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: bgColor ?? Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        // Clear button
        Expanded(
          child: ElevatedButton(
            onPressed: () => game.clearBet(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[900],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'CLEAR',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Spin button
        Expanded(
          child: ElevatedButton(
            onPressed: () => game.spin(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'SPIN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
