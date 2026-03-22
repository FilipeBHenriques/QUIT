import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:quit/game_result.dart';
import 'package:quit/usage_timer.dart';
import 'package:quit/screens/game_result_screen.dart';
import 'package:quit/theme/neon_palette.dart';
import 'package:quit/widgets/neon_button.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;

class FirstTimeGambleScreen extends StatefulWidget {
  final String packageName;
  final String appName;

  const FirstTimeGambleScreen({
    super.key,
    required this.packageName,
    required this.appName,
  });

  @override
  State<FirstTimeGambleScreen> createState() => _FirstTimeGambleScreenState();
}

class _FirstTimeGambleScreenState extends State<FirstTimeGambleScreen>
    with TickerProviderStateMixin {
  static const navigationChannel = MethodChannel('com.quit.app/navigation');
  static const blockedAppChannel = MethodChannel('com.quit.app/blocked_app');

  UsageTimer? _usageTimer;
  bool _loading = true;

  String packageName = '';
  String appName = '';
  int dailyLimitSeconds = 0;
  int remainingSeconds = 0;
  bool isBonusTime = false;
  int bonusSeconds = 0;

  late final AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    packageName = widget.packageName;
    appName = widget.appName;

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _initializeTimer();
    _loadBlockedAppInfo();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadBlockedAppInfo() async {
    try {
      final info = await blockedAppChannel.invokeMethod('getBlockedAppInfo');

      final prefs = await SharedPreferences.getInstance();
      final bonusAmount = prefs.getInt('bonus_amount_seconds') ?? 300;
      final dailyRanOutTimestamp =
          prefs.getInt('daily_time_ran_out_timestamp') ?? 0;

      if (info == null || info is! Map) return;

      final remaining = info['remainingSeconds'] ?? 0;

      if (mounted) {
        setState(() {
          if (info['packageName'] != null &&
              info['packageName'].toString().isNotEmpty) {
            packageName = info['packageName'];
          }
          if (info['appName'] != null &&
              info['appName'].toString().isNotEmpty) {
            appName = info['appName'];
          }

          dailyLimitSeconds = info['dailyLimitSeconds'] ?? 0;
          remainingSeconds = remaining;
          isBonusTime = dailyRanOutTimestamp > 0;
          bonusSeconds = isBonusTime ? bonusAmount : remaining;
        });
      }
    } catch (_) {}
  }

  Future<void> _initializeTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _usageTimer = UsageTimer(prefs);
    await _usageTimer?.checkAndResetIfNeeded();
    if (mounted) {
      setState(() => _loading = false);
      _entryController.forward();
    }
  }

  Future<bool> _grantBonusAndMarkChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dailyRanOutTimestamp =
          prefs.getInt('daily_time_ran_out_timestamp') ?? 0;
      bool bonusGranted = false;

      if (dailyRanOutTimestamp > 0) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastBonus = prefs.getInt('last_bonus_time') ?? 0;
        final refillSeconds =
            prefs.getInt('bonus_refill_interval_seconds') ?? 3600;
        final refillMs = refillSeconds * 1000;
        final cooldownAnchor = math.max(lastBonus, dailyRanOutTimestamp);
        final isBonusAvailable = (now - cooldownAnchor) >= refillMs;

        if (isBonusAvailable) {
          final bonusSecs = prefs.getInt('bonus_amount_seconds') ?? 300;
          final currentRemaining = prefs.getInt('remaining_seconds') ?? 0;
          final newRemaining = currentRemaining + bonusSecs;
          await prefs.setInt('remaining_seconds', newRemaining);
          await prefs.setInt('last_bonus_time', now);
          bonusGranted = true;
        }
      }

      final lastReset = prefs.getInt('timer_last_reset') ?? 0;
      if (lastReset == 0) {
        await prefs.setInt(
          'timer_last_reset',
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      await prefs.setBool('timer_first_choice_made', true);
      return bonusGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> _continueToApp() async {
    try {
      await _grantBonusAndMarkChoice();
      await navigationChannel.invokeMethod('launchApp', {
        'packageName': packageName,
      });
    } catch (_) {
      await navigationChannel.invokeMethod('goHome');
    }
  }

  Future<void> _closeToHome() async {
    try {
      await navigationChannel.invokeMethod('goHome');
    } catch (_) {}
  }

  Future<void> _goToGambleGame(String routePath) async {
    await _grantBonusAndMarkChoice();
    if (!mounted) return;
    final result = await context.push(routePath);
    if (result != null && result is GameResult) {
      _handleGameResult(result);
    }
  }

  Future<void> _handleGameResult(GameResult result) async {
    if (_usageTimer != null) {
      await _usageTimer!.reload();
    }
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultScreen(
            result: result,
            packageName: packageName,
            appName: appName,
          ),
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return '0:00';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final displaySeconds = isBonusTime ? bonusSeconds : remainingSeconds;

    if (_loading) {
      return const Scaffold(
        backgroundColor: NeonPalette.bg,
        body: Center(
          child: CircularProgressIndicator(
            color: NeonPalette.violet,
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NeonPalette.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _closeToHome,
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

              const SizedBox(height: 16),

              // App label
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: NeonPalette.rose,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    appName.isNotEmpty
                        ? appName.toUpperCase()
                        : 'APP BLOCKED',
                    style: const TextStyle(
                      fontSize: 11,
                      color: NeonPalette.textMuted,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Timer display
              _TimerCard(
                seconds: displaySeconds,
                isBonusTime: isBonusTime,
                formatTime: _formatTime,
              ),

              const SizedBox(height: 48),

              // Section label
              const Text(
                'CHOOSE YOUR GAME',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: NeonPalette.textMuted,
                  letterSpacing: 3,
                ),
              ),

              const SizedBox(height: 16),

              // Game cards — vertical stack for clarity
              _GameCard(
                icon: Icons.style_outlined,
                label: 'Blackjack',
                description: 'Beat the dealer',
                onPressed: () => _goToGambleGame('/blackjack'),
                accentColor: NeonPalette.mint,
              ),
              const SizedBox(height: 10),
              _GameCard(
                icon: LucideIcons.circleDot,
                label: 'Roulette',
                description: 'Spin the wheel',
                onPressed: () => _goToGambleGame('/roulette'),
                accentColor: NeonPalette.rose,
              ),
              const SizedBox(height: 10),
              _GameCard(
                icon: Icons.diamond_outlined,
                label: 'Mines',
                description: 'Find the diamonds',
                onPressed: () => _goToGambleGame('/mines'),
                accentColor: NeonPalette.cyan,
              ),

              const SizedBox(height: 40),

              // Continue button
              NeonButton(
                onPressed: _continueToApp,
                color: NeonPalette.surfaceSoft,
                borderColor: const Color(0xFF2A2E3F),
                glowColor: const Color(0xFFFFFFFF),
                textColor: Colors.white,
                glowOpacity: 0.08,
                padding: const EdgeInsets.symmetric(vertical: 18),
                borderRadius: 14,
                fontSize: 13,
                letterSpacing: 2.0,
                text: 'CONTINUE WITHOUT PLAYING',
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Timer Card
// ─────────────────────────────────────────────

class _TimerCard extends StatelessWidget {
  final int seconds;
  final bool isBonusTime;
  final String Function(int) formatTime;

  const _TimerCard({
    required this.seconds,
    required this.isBonusTime,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          isBonusTime ? 'BONUS TIME' : 'AVAILABLE TIME',
          style: TextStyle(
            color: NeonPalette.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: isBonusTime
                ? [NeonPalette.amber, const Color(0xFFFFF3CD)]
                : [Colors.white, Colors.white70],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            formatTime(seconds),
            style: const TextStyle(
              fontSize: 76,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (isBonusTime) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: NeonPalette.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: NeonPalette.amber.withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
            child: Text(
              'BONUS READY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: NeonPalette.amber,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Game Card
// ─────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onPressed;
  final Color accentColor;

  const _GameCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onPressed,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: NeonPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.18),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.20),
                  width: 0.5,
                ),
              ),
              child: Icon(icon, size: 18, color: accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: NeonPalette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      color: NeonPalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: accentColor.withValues(alpha: 0.45),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
