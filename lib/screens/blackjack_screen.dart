import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../games/blackjack_game.dart';
import 'package:quit/game_result.dart';
import 'package:quit/theme/neon_palette.dart';
import 'package:quit/widgets/game_header.dart';
import 'package:quit/widgets/neon_button.dart';

class BlackjackScreen extends StatefulWidget {
  const BlackjackScreen({super.key});

  @override
  State<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends State<BlackjackScreen> {
  late BlackjackGame game;
  int remainingTime = 0;
  bool isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRemainingTime();
  }

  Future<void> _loadRemainingTime() async {
    final prefs = await SharedPreferences.getInstance();
    final remaining = prefs.getInt('remaining_seconds') ?? 0;

    setState(() {
      remainingTime = remaining;
      isLoaded = true;
    });

    // Initialize game with callback
    game = BlackjackGame(
      betAmount: remainingTime,
      onGameComplete: _onGameComplete,
    );
  }

  void _onGameComplete(GameResult result) {
    // Return result to previous screen
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        backgroundColor: NeonPalette.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final minutes = remainingTime ~/ 60;
    final seconds = remainingTime % 60;
    final timeString = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: NeonPalette.bg,
      body: SafeArea(
        child: Column(
          children: [
            GameHeader(
              title: 'BLACKJACK',
              bettingTime: timeString,
              onBack: () => Navigator.of(context).pop(),
            ),

            Expanded(child: GameWidget(game: game)),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      color: Colors.black.withOpacity(0.75),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      child: Row(
        children: [
          Expanded(
            child: NeonButton(
              onPressed: () => game.hit(),
              color: NeonPalette.surfaceSoft,
              textColor: Colors.white,
              borderColor: NeonPalette.border,
              glowOpacity: 0.0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              borderRadius: 20,
              fontSize: 14,
              letterSpacing: 0.8,
              text: 'HIT',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: NeonButton(
              onPressed: () => game.stand(),
              color: NeonPalette.surfaceSoft,
              textColor: Colors.white,
              borderColor: NeonPalette.border,
              glowOpacity: 0.0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              borderRadius: 20,
              fontSize: 14,
              letterSpacing: 0.8,
              text: 'STAND',
            ),
          ),
        ],
      ),
    );
  }
}
