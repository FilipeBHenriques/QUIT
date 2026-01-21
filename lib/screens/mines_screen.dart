import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit/game_result.dart';
import '../games/mines_game.dart';
import '../games/mines_constants.dart';

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

  // Current game stats
  int diamondsFound = 0;
  double currentMultiplier = 1.0;
  int potentialWin = 0;

  // Animation controllers
  late AnimationController _buttonPulseController;
  late Animation<double> _buttonPulseAnimation;

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _loadRemainingTime();
  }

  void _initializeAnimations() {
    // Button pulse animation
    _buttonPulseController = AnimationController(
      duration: Duration(milliseconds: MinesConstants.pulseAnimationDuration),
      vsync: this,
    )..repeat(reverse: true);

    _buttonPulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _buttonPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _buttonPulseController.dispose();
    super.dispose();
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

    // Listen to stats updates
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

  void _cashOut() {
    _game.cashOut();
  }

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
        backgroundColor: MinesConstants.backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: MinesConstants.textColorPrimary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: MinesConstants.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: GameWidget(game: _game)),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height:
          MediaQuery.of(context).size.height *
          MinesConstants.topBarHeightPercent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: MinesConstants.textColorPrimary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  MinesConstants.gameTitle,
                  style: const TextStyle(
                    color: MinesConstants.textColorPrimary,
                    fontSize: MinesConstants.titleTextSize,
                    fontWeight: FontWeight.w300,
                    letterSpacing: MinesConstants.titleLetterSpacing,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'BETTING: ${MinesConstants.formatTime(remainingTime)}',
                  style: TextStyle(
                    color: MinesConstants.winColor.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 48), // Balance back button
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final canCashOut = diamondsFound > 0 && !_game.isGameOver;
    final canReset = _game.isGameOver;

    return Container(
      height:
          MediaQuery.of(context).size.height *
          MinesConstants.bottomControlsHeightPercent,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MinesConstants.backgroundColor,
        border: Border(
          top: BorderSide(color: MinesConstants.tileBorderColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats row
          _buildStatsRow(),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              // Reset button (only show when game over)
              if (canReset) Expanded(child: _buildResetButton()),

              // Cash out button (only show when diamonds found and game not over)
              if (canCashOut) ...[
                if (canReset) const SizedBox(width: 16),
                Expanded(flex: canReset ? 1 : 2, child: _buildCashOutButton()),
              ],

              // Show placeholder if no buttons
              if (!canCashOut && !canReset)
                Expanded(
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    child: Text(
                      'REVEAL TILES TO START',
                      style: TextStyle(
                        color: MinesConstants.textColorSecondary.withOpacity(
                          0.5,
                        ),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
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

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(
          label: MinesConstants.diamondsFoundLabel,
          value: '$diamondsFound/${MinesConstants.diamondCount}',
          color: MinesConstants.textColorPrimary,
        ),
        _buildStatItem(
          label: MinesConstants.multiplierLabel,
          value: MinesConstants.formatMultiplier(currentMultiplier),
          color: MinesConstants.textColorSecondary,
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: MinesConstants.textColorSecondary.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.w300,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildCashOutButton() {
    return AnimatedBuilder(
      animation: _buttonPulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _buttonPulseAnimation.value,
          child: ElevatedButton(
            onPressed: _cashOut,
            style: ElevatedButton.styleFrom(
              backgroundColor: MinesConstants.buttonColorPrimary,
              foregroundColor: MinesConstants.backgroundColor,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: 8,
              shadowColor: MinesConstants.winColor.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  MinesConstants.tileBorderRadius,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MinesConstants.cashOutButton,
                  style: const TextStyle(
                    fontSize: MinesConstants.buttonTextSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: MinesConstants.buttonLetterSpacing,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  MinesConstants.formatTime(potentialWin),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResetButton() {
    return OutlinedButton(
      onPressed: _reset,
      style: OutlinedButton.styleFrom(
        foregroundColor: MinesConstants.textColorPrimary,
        side: const BorderSide(color: MinesConstants.tileBorderColor, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MinesConstants.tileBorderRadius),
        ),
      ),
      child: const Text(
        MinesConstants.resetButton,
        style: TextStyle(
          fontSize: MinesConstants.buttonTextSize,
          fontWeight: FontWeight.bold,
          letterSpacing: MinesConstants.buttonLetterSpacing,
        ),
      ),
    );
  }
}
