import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit/game_result.dart';
import 'blackjack_screen.dart';
import 'roulette_screen.dart';
import 'mines_screen.dart';
import 'game_result_screen.dart';

class FirstTimeGambleScreen extends StatefulWidget {
  const FirstTimeGambleScreen({super.key});

  @override
  State<FirstTimeGambleScreen> createState() => _FirstTimeGambleScreenState();
}

class _FirstTimeGambleScreenState extends State<FirstTimeGambleScreen> {
  static const navigationChannel = MethodChannel('com.quit.app/navigation');
  static const blockedAppChannel = MethodChannel('com.quit.app/blocked_app');

  String packageName = '';
  String appName = '';
  int dailyLimitSeconds = 0;
  int remainingSeconds = 0;
  int bonusSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadBlockedAppInfo();
  }

  Future<void> _loadBlockedAppInfo() async {
    try {
      final info = await blockedAppChannel.invokeMethod('getBlockedAppInfo');
      final prefs = await SharedPreferences.getInstance();
      final bonusAmount = prefs.getInt('bonus_amount_seconds') ?? 300;
      
      setState(() {
        packageName = info['packageName'] ?? '';
        appName = info['appName'] ?? '';
        dailyLimitSeconds = info['dailyLimitSeconds'] ?? 0;
        remainingSeconds = info['remainingSeconds'] ?? 0;
        bonusSeconds = bonusAmount; // Show the bonus amount
      });
    } catch (e) {
      print('❌ Error loading blocked app info: $e');
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Helper function to grant bonus and mark user choice
  /// Returns true if bonus was granted, false otherwise
  Future<bool> _grantBonusAndMarkChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Grant the bonus time if this is a bonus scenario
      final dailyRanOutTimestamp = prefs.getInt('daily_time_ran_out_timestamp') ?? 0;
      bool bonusGranted = false;
      
      if (dailyRanOutTimestamp > 0) {
        // This is a bonus scenario - grant the bonus
        final bonusSeconds = prefs.getInt('bonus_amount_seconds') ?? 300; // Default 5 minutes
        final currentRemaining = prefs.getInt('remaining_seconds') ?? 0;
        final newRemaining = currentRemaining + bonusSeconds;
        
        await prefs.setInt('remaining_seconds', newRemaining);
        await prefs.setInt('last_bonus_time', DateTime.now().millisecondsSinceEpoch);
        
        print('🎁 Bonus granted! Added ${bonusSeconds}s. Remaining: ${currentRemaining}s → ${newRemaining}s');
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
    // Grant bonus and mark choice before starting the game
    await _grantBonusAndMarkChoice();
    print('🎰 User chose to gamble - starting game');
    
    // Navigate to game and wait for result
    final result = await Navigator.push<GameResult>(
      context,
      MaterialPageRoute(builder: (context) => gameScreen),
    );

    // If game returned a result, show result screen
    if (result != null && mounted) {
      // Navigate to result screen
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon/name
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
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
                        appName.isNotEmpty ? appName : 'Blocked App',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Time available message - showing BONUS time
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'You have',
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(bonusSeconds),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '(BONUS)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'available to use or gamble',
                        style: TextStyle(fontSize: 18, color: Colors.white70),
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

                // Game buttons
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    // Blackjack
                    SizedBox(
                      width: 110,
                      child: ElevatedButton(
                        onPressed: () =>
                            _goToGambleGame(const BlackjackScreen()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.casino, size: 28),
                            SizedBox(height: 6),
                            Text(
                              'Blackjack',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Roulette
                    SizedBox(
                      width: 110,
                      child: ElevatedButton(
                        onPressed: () =>
                            _goToGambleGame(const RouletteScreen()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.album, size: 28),
                            SizedBox(height: 6),
                            Text(
                              'Roulette',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Mines
                    SizedBox(
                      width: 110,
                      child: ElevatedButton(
                        onPressed: () => _goToGambleGame(const MinesScreen()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[850],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.grid_on, size: 28),
                            SizedBox(height: 6),
                            Text(
                              'Mines',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

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
