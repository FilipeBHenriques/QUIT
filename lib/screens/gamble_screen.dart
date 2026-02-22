import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit/game_result.dart';
import 'package:quit/usage_timer.dart';
import 'package:quit/screens/blackjack_screen.dart';
import 'package:quit/screens/roulette_screen.dart';
import 'package:quit/screens/mines_screen.dart';
import 'package:quit/screens/game_result_screen.dart';
import 'package:quit/theme/game_icons.dart';
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

class _FirstTimeGambleScreenState extends State<FirstTimeGambleScreen> {
  static const navigationChannel = MethodChannel('com.quit.app/navigation');
  static const blockedAppChannel = MethodChannel('com.quit.app/blocked_app');

  UsageTimer? _usageTimer;
  bool _loading = true;

  // State variables for UI
  String packageName = '';
  String appName = '';
  int dailyLimitSeconds = 0;
  int remainingSeconds = 0;
  bool isBonusTime = false;
  int bonusSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with widget values first
    packageName = widget.packageName;
    appName = widget.appName;

    _initializeTimer();
    _loadBlockedAppInfo();
  }

  Future<void> _loadBlockedAppInfo() async {
    try {
      final info = await blockedAppChannel.invokeMethod('getBlockedAppInfo');

      final prefs = await SharedPreferences.getInstance();
      final bonusAmount = prefs.getInt('bonus_amount_seconds') ?? 300;
      final dailyRanOutTimestamp =
          prefs.getInt('daily_time_ran_out_timestamp') ?? 0;

      // Safety check for info map
      if (info == null || info is! Map) return;

      final remaining = info['remainingSeconds'] ?? 0;

      if (mounted) {
        setState(() {
          // If native sent valid info, correct widget params if needed
          if (info['packageName'] != null &&
              info['packageName'].toString().isNotEmpty) {
            packageName = info['packageName'];
          }
          if (info['appName'] != null &&
              info['appName'].toString().isNotEmpty) {
            appName = info['appName'];
          }

          dailyLimitSeconds = info['dailyLimitSeconds'] ?? 0;

          // Use the native remaining time as it's the source of truth
          // BUT if we have a UsageTimer, maybe respect it?
          // Actually user requested specifically: remainingSeconds = remaining;
          remainingSeconds = remaining;

          // Show bonus time if daily ran out, otherwise show remaining daily time
          isBonusTime = dailyRanOutTimestamp > 0;
          bonusSeconds = isBonusTime ? bonusAmount : remaining;
        });
        print(
          '📦 Loaded info: $packageName ($appName), rem: $remainingSeconds',
        );
      }
    } catch (e) {
      print('❌ Error loading blocked app info: $e');
    }
  }

  Future<void> _initializeTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _usageTimer = UsageTimer(prefs);
    await _usageTimer?.checkAndResetIfNeeded();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<bool> _grantBonusAndMarkChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Grant the bonus time if this is a bonus scenario
      final dailyRanOutTimestamp =
          prefs.getInt('daily_time_ran_out_timestamp') ?? 0;
      bool bonusGranted = false;

      if (dailyRanOutTimestamp > 0) {
        // This is a bonus scenario - grant the bonus
        final bonusSeconds =
            prefs.getInt('bonus_amount_seconds') ?? 300; // Default 5 minutes
        final currentRemaining = prefs.getInt('remaining_seconds') ?? 0;
        final newRemaining = currentRemaining + bonusSeconds;

        await prefs.setInt('remaining_seconds', newRemaining);
        await prefs.setInt(
          'last_bonus_time',
          DateTime.now().millisecondsSinceEpoch,
        );

        print(
          '🎁 Bonus granted! Added ${bonusSeconds}s. Remaining: ${currentRemaining}s → ${newRemaining}s',
        );
        bonusGranted = true;
      }

      // Start the reset timer countdown if not already started
      final lastReset = prefs.getInt('timer_last_reset') ?? 0;
      if (lastReset == 0) {
        await prefs.setInt(
          'timer_last_reset',
          DateTime.now().millisecondsSinceEpoch,
        );
      }

      await prefs.setBool(
        'timer_first_choice_made',
        true,
      ); // Mark that user made a choice

      return bonusGranted;
    } catch (e) {
      print('❌ Error granting bonus: $e');
      return false;
    }
  }

  Future<void> _continueToApp() async {
    try {
      // Grant bonus and mark choice
      await _grantBonusAndMarkChoice();

      print('✅ User chose to continue - launching app');

      // Launch the blocked app
      await navigationChannel.invokeMethod('launchApp', {
        'packageName': packageName,
      });
    } catch (e) {
      print('❌ Error continuing to app: $e');
      // Fallback: go home
      await navigationChannel.invokeMethod('goHome');
    }
  }

  Future<void> _goToGambleGame(Widget gameScreen) async {
    await _grantBonusAndMarkChoice();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => gameScreen),
    );

    if (result != null && result is GameResult) {
      _handleGameResult(result);
    }
  }

  Future<void> _handleGameResult(GameResult result) async {
    if (_usageTimer != null) {
      if (result.won) {
        // Did user implement addBonus? Assuming timeChange is positive, we can deduct or add?
        // Wait, UsageTimer logic: "used" decreases if we win time back? Or "limit" increases?
        // Usually "bonus" implies adding to a separate pool or reducing "used".
        // Let's assume UsageTimer has a method or we manipulate used/remaining.
        // Based on GameResultScreen logic seen earlier, it updates 'remaining_seconds' directly.
        // So we might just need to reload timer.
        await _usageTimer!.reload();
      } else {
        // Lost time.
        await _usageTimer!.reload();
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameResultScreen(
            result: result,
            packageName: packageName, // Use resolved state variable
            appName: appName, // Use resolved state variable
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

    // Shiny Gradient (Gold for bonus, White for normal)
    final shinyGradient = LinearGradient(
      colors: [
        isBonusTime ? const Color(0xFFFBBF24) : Colors.white,
        isBonusTime ? const Color(0xFFFFF7ED) : Colors.white70,
        isBonusTime ? const Color(0xFFFBBF24) : Colors.white,
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: const GradientRotation(0.5),
    );

    if (_loading) {
      return const Scaffold(
        backgroundColor: NeonPalette.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: NeonPalette.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact Header
                const Icon(
                  Icons.access_time_outlined,
                  size: 40,
                  color: NeonPalette.textMuted,
                ),
                const SizedBox(height: 8),
                Text(
                  appName.isNotEmpty ? appName.toUpperCase() : 'APP BLOCKED',
                  style: const TextStyle(
                    fontSize: 12,
                    color: NeonPalette.textMuted,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 32),

                // Main Timer Card
                const Text(
                  'AVAILABLE TIME',
                  style: TextStyle(
                    color: NeonPalette.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),

                ShaderMask(
                  shaderCallback: (bounds) =>
                      shinyGradient.createShader(bounds),
                  child: Text(
                    _formatTime(displaySeconds),
                    style: const TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                      letterSpacing: -3,
                    ),
                  ),
                ),

                if (isBonusTime) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'BONUS READY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: NeonPalette.bg,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 48),

                // Games Section
                const Text(
                  'CHOOSE YOUR PATH',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: NeonPalette.textMuted,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),

                // Compact Game Selection
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildCompactGameItem(
                      icon: Icons.style_outlined,
                      label: 'Blackjack',
                      onPressed: () => _goToGambleGame(const BlackjackScreen()),
                      color: const Color(0xFF111827),
                    ),
                    _buildCompactGameItem(
                      icon: LucideIcons.circleDot,
                      label: 'Roulette',
                      onPressed: () => _goToGambleGame(const RouletteScreen()),
                      color: const Color(0xFF111827),
                    ),
                    _buildCompactGameItem(
                      icon: kDiamond,
                      label: 'Mines',
                      onPressed: () => _goToGambleGame(const MinesScreen()),
                      color: NeonPalette.surfaceSoft,
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // Primary Action
                SizedBox(
                  width: double.infinity,
                  child: NeonButton(
                    onPressed: _continueToApp,
                    color: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    borderRadius: 22,
                    fontSize: 15,
                    letterSpacing: 1.2,
                    text: 'CONTINUE TO APP',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactGameItem({
    required IconData icon,
    String? iconGlyph,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 164,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.04),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            iconGlyph == null
                ? Icon(icon, size: 18, color: Colors.white)
                : Text(
                    iconGlyph,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Risk for extra time',
              style: TextStyle(color: NeonPalette.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
