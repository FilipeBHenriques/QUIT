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

class _RouletteScreenState extends State<RouletteScreen> {
  late RouletteGame _game;
  int remainingTime = 0;
  bool isLoaded = false;
  BetType? selectedBet;
  int? _resultNumber;
  bool? _resultWon;

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

    _game = RouletteGame(
      betAmount: remainingTime,
      onGameComplete: _onGameComplete,
      onBetChanged: _onBetChanged,
      onResultReady: _onResultReady,
    );
  }

  void _onBetChanged(BetType? newBet) {
    setState(() {
      selectedBet = newBet;
      _resultNumber = null;
      _resultWon = null;
    });
  }

  void _onResultReady(int number, bool won) {
    if (!mounted) return;
    setState(() {
      _resultNumber = number;
      _resultWon = won;
    });
  }

  void _onGameComplete(GameResult result) {
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        backgroundColor: NeonPalette.bg,
        body: Center(
          child: CircularProgressIndicator(
            color: NeonPalette.rose,
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
              title: 'ROULETTE',
              bettingTime: timeString,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(flex: 3, child: GameWidget(game: _game)),
            _buildMessagesArea(),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Color _getResultColor(int number) {
    if (number == 0) return const Color(0xFF00FF88);
    return RouletteNumbers.isBlack(number)
        ? const Color(0xFF9AAABF)
        : NeonPalette.rose;
  }

  Widget _buildMessagesArea() {
    if (_resultNumber != null) {
      final number = _resultNumber!;
      final won = _resultWon ?? false;
      final numColor = _getResultColor(number);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$number',
              style: TextStyle(
                color: numColor,
                fontSize: 60,
                fontWeight: FontWeight.w200,
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    color: numColor.withValues(alpha: 0.80),
                    blurRadius: 24,
                  ),
                  Shadow(
                    color: numColor.withValues(alpha: 0.35),
                    blurRadius: 48,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              won ? 'YOU WIN' : 'YOU LOSE',
              style: TextStyle(
                color: won ? NeonPalette.mint : NeonPalette.rose,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 5,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: StreamBuilder<String>(
        stream: _game.messageStream,
        initialData: '',
        builder: (context, snapshot) {
          final msg = snapshot.data ?? '';
          if (msg.isEmpty) return const SizedBox.shrink();
          return Center(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w300,
                letterSpacing: 4,
                color: NeonPalette.textMuted,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: NeonPalette.bg.withValues(alpha: 0.90),
            border: Border(
              top: BorderSide(color: NeonPalette.border, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBetButtons(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NeonButton(
                      onPressed: () {
                        _game.clearBet();
                        setState(() => selectedBet = null);
                      },
                      color: Colors.transparent,
                      textColor: NeonPalette.textMuted,
                      borderColor: NeonPalette.border,
                      glowOpacity: 0.0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: 12,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      text: 'CLEAR',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: NeonButton(
                      onPressed: () => _game.spin(),
                      color: NeonPalette.rose.withValues(alpha: 0.08),
                      textColor: NeonPalette.rose,
                      borderColor: NeonPalette.rose.withValues(alpha: 0.40),
                      glowColor: NeonPalette.rose,
                      glowOpacity: 0.25,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: 12,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
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
            _buildBetButton(BetType.white(), NeonPalette.rose),
            const SizedBox(width: 6),
            _buildBetButton(BetType.black(), const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            _buildBetButton(BetType.straight(0), NeonPalette.mint),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildBetButton(BetType.even()),
            const SizedBox(width: 6),
            _buildBetButton(BetType.odd()),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildBetButton(BetType.low()),
            const SizedBox(width: 6),
            _buildBetButton(BetType.high()),
          ],
        ),
      ],
    );
  }

  Widget _buildBetButton(BetType betType, [Color? accentColor]) {
    final accent = accentColor ?? NeonPalette.textMuted;
    final isSelected = selectedBet?.name == betType.name;

    return Expanded(
      child: NeonButton(
        onPressed: () => _game.placeBet(betType),
        color: isSelected
            ? accent.withValues(alpha: 0.20)
            : NeonPalette.surfaceSoft,
        textColor: isSelected ? accent : NeonPalette.textMuted,
        borderColor: isSelected ? accent : NeonPalette.border,
        glowColor: accent,
        glowOpacity: isSelected ? 0.45 : 0.0,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        borderRadius: 10,
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: 0.5,
        text: '${_displayBetName(betType).toUpperCase()}  ×${betType.payout + 1}',
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
