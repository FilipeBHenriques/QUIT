import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit/game_result.dart';
import 'dart:ui';
import '../games/mines_game.dart';
import '../games/mines_constants.dart';
import '../theme/neon_palette.dart';
import '../widgets/game_header.dart';
import '../widgets/neon_button.dart';

class MinesScreen extends StatefulWidget {
  const MinesScreen({super.key});

  @override
  State<MinesScreen> createState() => _MinesScreenState();
}

class _MinesScreenState extends State<MinesScreen>
    with TickerProviderStateMixin {
  late MinesGame _game;
  int remainingTime = 0;
  bool isLoaded = false;

  int diamondsFound = 0;
  double currentMultiplier = 1.0;
  int potentialWin = 0;

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
      potentialWin = remaining;
      isLoaded = true;
    });

    _game = MinesGame(
      betAmount: remainingTime,
      onGameComplete: _onGameComplete,
    );

    _game.statsStream.listen((stats) {
      if (mounted) {
        setState(() {
          diamondsFound = stats['diamondsFound'] as int;
          currentMultiplier = stats['multiplier'] as double;
          potentialWin = stats['potentialWin'] as int;
        });
      }
    });
  }

  void _onGameComplete(GameResult result) {
    Navigator.pop(context, result);
  }

  void _cashOut() => _game.cashOut();

  void _reset() {
    _game.resetGame();
    setState(() {
      diamondsFound = 0;
      currentMultiplier = 1.0;
      potentialWin = remainingTime;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        backgroundColor: NeonPalette.bg,
        body: Center(
          child: CircularProgressIndicator(
            color: NeonPalette.cyan,
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NeonPalette.bg,
      body: SafeArea(
        child: Column(
          children: [
            GameHeader(
              title: MinesConstants.gameTitle,
              bettingTime: MinesConstants.formatTime(remainingTime),
              onBack: () => Navigator.pop(context),
            ),
            Expanded(child: GameWidget(game: _game)),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final canCashOut = diamondsFound > 0 && !_game.isGameOver;
    final canReset = _game.isGameOver;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          decoration: BoxDecoration(
            color: NeonPalette.bg.withValues(alpha: 0.90),
            border: Border(
              top: BorderSide(color: NeonPalette.border, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatsRow(),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (canReset) Expanded(child: _buildResetButton()),
                  if (canCashOut) ...[
                    if (canReset) const SizedBox(width: 12),
                    Expanded(
                      flex: canReset ? 1 : 2,
                      child: _buildCashOutButton(),
                    ),
                  ],
                  if (!canCashOut && !canReset)
                    Expanded(
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        child: const Text(
                          'REVEAL TILES TO BEGIN',
                          style: TextStyle(
                            color: NeonPalette.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2.5,
                          ),
                        ),
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

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: MinesConstants.diamondsFoundLabel,
            value: '$diamondsFound/${MinesConstants.diamondCount}',
            color: diamondsFound > 0 ? NeonPalette.cyan : NeonPalette.textMuted,
          ),
        ),
        Container(
          width: 0.5,
          height: 36,
          color: NeonPalette.border,
        ),
        Expanded(
          child: _StatChip(
            label: MinesConstants.multiplierLabel,
            value: MinesConstants.formatMultiplier(currentMultiplier),
            color: currentMultiplier > 1.0
                ? NeonPalette.mint
                : NeonPalette.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildCashOutButton() {
    return NeonButton(
      onPressed: _cashOut,
      color: NeonPalette.cyan.withValues(alpha: 0.07),
      textColor: NeonPalette.cyan,
      borderColor: NeonPalette.cyan.withValues(alpha: 0.35),
      glowColor: NeonPalette.cyan,
      glowOpacity: 0.22,
      padding: const EdgeInsets.symmetric(vertical: 16),
      borderRadius: 12,
      fontSize: 13,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
      text: '${MinesConstants.cashOutButton}  ${MinesConstants.formatTime(potentialWin)}',
    );
  }

  Widget _buildResetButton() {
    return NeonButton(
      onPressed: _reset,
      color: Colors.transparent,
      textColor: NeonPalette.textMuted,
      borderColor: NeonPalette.border,
      glowOpacity: 0.0,
      padding: const EdgeInsets.symmetric(vertical: 16),
      borderRadius: 12,
      fontSize: 13,
      letterSpacing: 1.5,
      text: MinesConstants.resetButton,
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NeonPalette.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            shadows: color != NeonPalette.textMuted
                ? [
                    Shadow(
                      color: color.withValues(alpha: 0.55),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}
