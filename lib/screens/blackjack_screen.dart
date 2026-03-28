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

    game = BlackjackGame(
      betAmount: remainingTime,
      onGameComplete: _onGameComplete,
    );
  }

  void _onGameComplete(GameResult result) {
    if (!mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        backgroundColor: NeonPalette.bg,
        body: Center(
          child: CircularProgressIndicator(
            color: NeonPalette.mint,
            strokeWidth: 1.5,
          ),
        ),
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
      decoration: BoxDecoration(
        color: NeonPalette.bg,
        border: Border(
          top: BorderSide(color: NeonPalette.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Row(
        children: [
          Expanded(
            child: NeonButton(
              onPressed: () => game.hit(),
              color: NeonPalette.mint.withValues(alpha: 0.07),
              textColor: NeonPalette.mint,
              borderColor: NeonPalette.mint.withValues(alpha: 0.35),
              glowColor: NeonPalette.mint,
              glowOpacity: 0.20,
              padding: const EdgeInsets.symmetric(vertical: 18),
              borderRadius: 14,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              text: 'HIT',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: NeonButton(
              onPressed: () => game.stand(),
              color: NeonPalette.rose.withValues(alpha: 0.07),
              textColor: NeonPalette.rose,
              borderColor: NeonPalette.rose.withValues(alpha: 0.35),
              glowColor: NeonPalette.rose,
              glowOpacity: 0.18,
              padding: const EdgeInsets.symmetric(vertical: 18),
              borderRadius: 14,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.5,
              text: 'STAND',
            ),
          ),
        ],
      ),
    );
  }
}
