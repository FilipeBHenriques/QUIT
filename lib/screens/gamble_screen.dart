import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit/game_result.dart';
import 'blackjack_screen.dart';
import 'roulette_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _loadBlockedAppInfo();
  }

  Future<void> _loadBlockedAppInfo() async {
    try {
      final info = await blockedAppChannel.invokeMethod('getBlockedAppInfo');
      setState(() {
        packageName = info['packageName'] ?? '';
        appName = info['appName'] ?? '';
        dailyLimitSeconds = info['dailyLimitSeconds'] ?? 0;
        remainingSeconds = info['remainingSeconds'] ?? 0;
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

  Future<void> _continueToApp() async {
    try {
      // Start the reset timer countdown
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'timer_last_reset',
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setBool(
        'timer_first_choice_made',
        true,
      ); // Mark that user made a choice

      print('✅ User chose to continue - starting timer countdown');

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

                // Time available message
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'You have',
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(remainingSeconds),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'available today',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Blackjack
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _goToGambleGame(const BlackjackScreen()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.casino, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'Blackjack',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Roulette
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            _goToGambleGame(const RouletteScreen()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[900],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.album, size: 32),
                            SizedBox(height: 8),
                            Text(
                              'Roulette',
                              style: TextStyle(
                                fontSize: 16,
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
