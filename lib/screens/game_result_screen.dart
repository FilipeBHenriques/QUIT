import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:quit/game_result.dart';
import 'package:quit/services/stats_service.dart';
import 'package:quit/theme/neon_palette.dart';
import 'package:quit/widgets/neon_button.dart';

class GameResultScreen extends StatefulWidget {
  final GameResult result;
  final String packageName;
  final String appName;

  const GameResultScreen({
    super.key,
    required this.result,
    required this.packageName,
    required this.appName,
  });

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen>
    with TickerProviderStateMixin {
  static const navigationChannel = MethodChannel('com.quit.app/navigation');

  late AnimationController _scaleController;
  late AnimationController _numberController;
  late Animation<double> _scaleAnimation;
  Animation<int>? _numberAnimation;

  int initialTime = 0;
  int finalTime = 0;
  bool hasTime = true;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTimeData();
  }

  void _initializeAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _numberController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _scaleController.forward();
  }

  Future<void> _loadTimeData() async {
    final prefs = await SharedPreferences.getInstance();
    final currentRemaining = prefs.getInt('remaining_seconds') ?? 0;
    initialTime = currentRemaining;

    final newRemaining = math.max(0, currentRemaining + widget.result.timeChange);
    finalTime = newRemaining;
    hasTime = finalTime > 0;

    await prefs.setInt('remaining_seconds', finalTime);

    if (widget.result.timeChange < 0) {
      final currentUsed = prefs.getInt('used_today_seconds') ?? 0;
      await prefs.setInt(
        'used_today_seconds',
        currentUsed + widget.result.timeChange.abs(),
      );
    } else {
      final currentUsed = prefs.getInt('used_today_seconds') ?? 0;
      final newUsed = math.max(0, currentUsed - widget.result.timeChange);
      await prefs.setInt('used_today_seconds', newUsed);
    }

    _numberAnimation = IntTween(begin: initialTime, end: finalTime).animate(
      CurvedAnimation(parent: _numberController, curve: Curves.easeOutCubic),
    );

    // Record this game session for statistics
    await StatsService.recordSession(GameSession(
      gameName: widget.result.gameName,
      won: widget.result.won,
      timeBetSeconds: widget.result.timeChange.abs(),
      timeResultSeconds: widget.result.timeChange,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      appPackage: widget.packageName,
      appName: widget.appName,
    ));

    setState(() => _isLoaded = true);
    _numberController.forward();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _continue() async {
    if (hasTime) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastReset = prefs.getInt('timer_last_reset') ?? 0;
        if (lastReset == 0) {
          await prefs.setInt(
            'timer_last_reset',
            DateTime.now().millisecondsSinceEpoch,
          );
        }
        await prefs.setBool('timer_first_choice_made', true);
        await navigationChannel.invokeMethod('launchApp', {
          'packageName': widget.packageName,
        });
      } catch (_) {
        await navigationChannel.invokeMethod('goHome');
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastReset = prefs.getInt('timer_last_reset') ?? 0;
        if (lastReset == 0) {
          await prefs.setInt(
            'timer_last_reset',
            DateTime.now().millisecondsSinceEpoch,
          );
          await prefs.setBool('timer_first_choice_made', true);
        }
        await navigationChannel.invokeMethod('goHome');
      } catch (_) {
        await navigationChannel.invokeMethod('goHome');
      }
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWin = widget.result.won;
    final primaryColor = isWin ? NeonPalette.mint : NeonPalette.rose;
    final headline = isWin ? 'YOU WON' : 'YOU LOST';
    final subhead = isWin
        ? 'Nice play. Time added to your balance.'
        : 'Rough hand. Time was deducted.';

    return Scaffold(
      backgroundColor: NeonPalette.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Close
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () async =>
                        navigationChannel.invokeMethod('goHome'),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: NeonPalette.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: NeonPalette.border,
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: NeonPalette.textMuted,
                        size: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Result icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.08),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.22),
                        blurRadius: 28,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.08),
                        blurRadius: 60,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    isWin ? Icons.check_rounded : Icons.close_rounded,
                    color: primaryColor,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                // Headline
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Text(
                    headline,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: primaryColor.withValues(alpha: 0.7),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  subhead,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: NeonPalette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 40),

                // Time change card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.22),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.12),
                        blurRadius: 24,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isWin ? 'TIME GAINED' : 'TIME LOST',
                        style: const TextStyle(
                          color: NeonPalette.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.result.timeChangeFormattedMinutes,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 62,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(
                              color: primaryColor.withValues(alpha: 0.65),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Time remaining counter
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: NeonPalette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: NeonPalette.border,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TIME REMAINING',
                        style: TextStyle(
                          color: NeonPalette.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _isLoaded && _numberAnimation != null
                          ? AnimatedBuilder(
                              animation: _numberAnimation!,
                              builder: (context, _) => Text(
                                _formatTime(_numberAnimation!.value),
                                style: TextStyle(
                                  color: hasTime
                                      ? NeonPalette.text
                                      : NeonPalette.rose,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox(
                              height: 42,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: NeonPalette.textMuted,
                                  strokeWidth: 1.5,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                NeonButton(
                  onPressed: _continue,
                  color: NeonPalette.surfaceSoft,
                  borderColor: const Color(0xFF2A2E3F),
                  glowColor: Colors.white,
                  textColor: Colors.white,
                  glowOpacity: hasTime ? 0.10 : 0.0,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  borderRadius: 14,
                  fontSize: 13,
                  letterSpacing: 2.0,
                  text: hasTime ? 'CONTINUE TO APP' : 'GO HOME',
                ),

                if (!hasTime) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'No time remaining. Try again tomorrow.',
                    style: TextStyle(
                      color: NeonPalette.textMuted,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
