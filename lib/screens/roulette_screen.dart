import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit/game_result.dart';
import 'dart:ui';
import '../games/roulette_game.dart';
import '../games/roulette_constants.dart';
import '../theme/neon_palette.dart';
import '../widgets/game_header.dart';
import '../widgets/neon_button.dart';

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
              title: 'ROULETTE',
              bettingTime: timeString,
              onBack: () => Navigator.of(context).pop(),
            ),

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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.black.withOpacity(0.75),
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
                    child: NeonButton(
                      onPressed: () {
                        _game.clearBet();
                        setState(() {
                          selectedBet = null;
                        });
                      },
                      color: NeonPalette.surfaceSoft,
                      borderColor: NeonPalette.border,
                      glowOpacity: 0.0,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      borderRadius: 20,
                      fontSize: 14,
                      letterSpacing: 0.8,
                      text: 'CLEAR',
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Spin
                  Expanded(
                    flex: 2,
                    child: NeonButton(
                      onPressed: () => _game.spin(),
                      color: NeonPalette.surfaceSoft,
                      textColor: Colors.white,
                      borderColor: NeonPalette.border,
                      glowOpacity: 0.0,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      borderRadius: 20,
                      fontSize: 14,
                      letterSpacing: 0.8,
                      text: 'SPIN',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBetButtons() {
    return Column(
      children: [
        Row(
          children: [
            // Red (Visual Red -> Logic White)
            _buildBetButton(BetType.white(), NeonPalette.rose),
            const SizedBox(width: 8),
            // Black
            _buildBetButton(BetType.black(), NeonPalette.surfaceSoft),
            const SizedBox(width: 8),
            // Green (0)
            _buildBetButton(BetType.straight(0), NeonPalette.mint),
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
    final backgroundColor = NeonPalette.surfaceSoft;

    return Expanded(
      child: AnimatedBuilder(
        animation: _borderAnimation,
        builder: (context, child) {
          final isSelected = selectedBet?.name == betType.name;
          return NeonButton(
            onPressed: () => _game.placeBet(betType),
            color: backgroundColor,
            textColor: Colors.white,
            borderColor: isSelected ? const Color(0xFFEF4444) : NeonPalette.border,
            glowOpacity: isSelected ? (_borderAnimation.value * 0.22) : 0.0,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            borderRadius: 20,
            fontSize: 12,
            letterSpacing: 0.5,
            text:
                '${_displayBetName(betType).toUpperCase()}  x${betType.payout + 1}',
          );
        },
      ),
    );
  }

  String _displayBetName(BetType betType) {
    if (betType.name.startsWith('Straight')) return '0';
    if (betType.name.startsWith('Low')) return 'Low';
    if (betType.name.startsWith('High')) return 'High';
    return betType.name;
  }
}
