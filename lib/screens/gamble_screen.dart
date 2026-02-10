import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit/widgets/game_card.dart';
import 'package:quit/game_result.dart';
import 'package:quit/usage_timer.dart';
import 'package:quit/screens/blackjack_screen.dart';
import 'package:quit/screens/roulette_screen.dart';
import 'package:quit/screens/mines_screen.dart';
import 'package:quit/screens/game_result_screen.dart';
import 'dart:ui' show FontFeature;

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
    final theme = Theme.of(context);

    // Use state variables logic as requested
    // If bonus is active, show bonus amount? Or show remaining?
    // The user's code snippet: bonusSeconds = isBonusTime ? bonusAmount : remaining;
    // So we should display bonusSeconds if we want to show "time available"

    final displaySeconds = isBonusTime ? bonusSeconds : remainingSeconds;

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App info card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 64,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        // Use local appName
                        appName.isNotEmpty ? appName : 'Blocked App',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Time available card
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isBonusTime
                        ? const Color(0xFFFBBF24).withOpacity(0.1)
                        : const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isBonusTime
                          ? const Color(0xFFFBBF24)
                          : Colors.white10,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'You have',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatTime(displaySeconds),
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: isBonusTime
                              ? const Color(0xFFFBBF24)
                              : Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (isBonusTime) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBBF24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'BONUS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'available to use or gamble',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Gamble offer
                const Text(
                  'Want to win more time?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // Game cards
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    GameCard(
                      icon: Icons.style, // Spade/Cards substitute
                      label: 'Blackjack',
                      variant: GameCardVariant.success,
                      onClick: () => _goToGambleGame(const BlackjackScreen()),
                    ),
                    GameCard(
                      icon: Icons.adjust, // Roulette substitute
                      label: 'Roulette',
                      variant: GameCardVariant.destructive,
                      onClick: () => _goToGambleGame(const RouletteScreen()),
                    ),
                    GameCard(
                      icon: Icons.grid_on, // Mines substitute
                      label: 'Mines',
                      variant: GameCardVariant.muted,
                      onClick: () => _goToGambleGame(const MinesScreen()),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continueToApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue to App',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
