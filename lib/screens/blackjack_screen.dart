import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../games/blackjack_game.dart';
import 'package:quit/game_result.dart';
import 'package:quit/theme/neon_palette.dart';
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
        child: Stack(
          children: [
            // Flame game canvas
            GameWidget(game: game),

            // Top bar with bet amount
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: IntrinsicWidth(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(color: Colors.white24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0EA5E9).withOpacity(0.25),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'BLACKJACK',
                              style: TextStyle(
                                color: NeonPalette.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 3.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'BETTING: $timeString',
                              style: const TextStyle(
                                color: Color(0xFF93C5FD),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Game controls overlay
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hit button
                  Expanded(
                    child: NeonButton(
                      onPressed: () => game.hit(),
                      color: const Color(0xFF0EA5E9),
                      borderColor: const Color(0xFF7DD3FC),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      borderRadius: 22,
                      fontSize: 18,
                      letterSpacing: 1.2,
                      text: 'HIT',
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Stand button
                  Expanded(
                    child: NeonButton(
                      onPressed: () => game.stand(),
                      color: const Color(0xFFEF4444),
                      borderColor: const Color(0xFFFCA5A5),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      borderRadius: 22,
                      fontSize: 18,
                      letterSpacing: 1.2,
                      text: 'STAND',
                    ),
                  ),
                ],
              ),
            ),

            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: NeonPalette.text),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
