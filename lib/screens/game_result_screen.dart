import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:quit/game_result.dart';

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
  Animation<int>? _numberAnimation; // Nullable until initialized

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
    // Scale animation for the result text
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Number counter animation
    _numberController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleController.forward();
  }

  Future<void> _loadTimeData() async {
    final prefs = await SharedPreferences.getInstance();

    // Get current remaining time
    final currentRemaining = prefs.getInt('remaining_seconds') ?? 0;
    initialTime = currentRemaining;

    // Calculate new time after applying result
    final newRemaining = math.max(
      0,
      currentRemaining + widget.result.timeChange,
    );
    finalTime = newRemaining;
    hasTime = finalTime > 0;

    // Save the new time
    await prefs.setInt('remaining_seconds', finalTime);

    // Also update used_today counter
    if (widget.result.timeChange < 0) {
      // Lost time - add to used counter
      final currentUsed = prefs.getInt('used_today_seconds') ?? 0;
      await prefs.setInt(
        'used_today_seconds',
        currentUsed + widget.result.timeChange.abs(),
      );
    } else {
      // Won time - subtract from used counter (if possible)
      final currentUsed = prefs.getInt('used_today_seconds') ?? 0;
      final newUsed = math.max(0, currentUsed - widget.result.timeChange);
      await prefs.setInt('used_today_seconds', newUsed);
    }

    // Start the number animation
    _numberAnimation = IntTween(begin: initialTime, end: finalTime).animate(
      CurvedAnimation(parent: _numberController, curve: Curves.easeOutCubic),
    );

    setState(() {
      _isLoaded = true;
    });

    _numberController.forward();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _continue() async {
    if (hasTime) {
      // Has time - launch the app
      try {
        // Start the reset timer countdown (if not already started)
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
      } catch (e) {
        print('❌ Error launching app: $e');
        await navigationChannel.invokeMethod('goHome');
      }
    } else {
      // No time - start the 24h countdown so it resets tomorrow
      try {
        final prefs = await SharedPreferences.getInstance();

        // If timer hasn't started yet, start it now (so it resets in 24h)
        final lastReset = prefs.getInt('timer_last_reset') ?? 0;
        if (lastReset == 0) {
          await prefs.setInt(
            'timer_last_reset',
            DateTime.now().millisecondsSinceEpoch,
          );
          await prefs.setBool('timer_first_choice_made', true);
          print('⏰ Started 24h countdown - will reset tomorrow');
        }

        await navigationChannel.invokeMethod('goHome');
      } catch (e) {
        print('❌ Error going home: $e');
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
    final primaryColor = isWin ? Colors.greenAccent : Colors.redAccent;
    final secondaryColor = isWin ? Colors.green[700] : Colors.red[900];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Result text with scale animation
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Text(
                    isWin ? 'YOU WON!' : 'YOU LOST',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: primaryColor.withOpacity(0.8),
                          offset: Offset.zero,
                          blurRadius: 30,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Time change display
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: secondaryColor?.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isWin ? 'TIME GAINED' : 'TIME LOST',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.result.timeChangeFormattedMinutes,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Animated time remaining counter
                _isLoaded && _numberAnimation != null
                    ? AnimatedBuilder(
                        animation: _numberAnimation!,
                        builder: (context, child) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'TIME REMAINING',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatTime(_numberAnimation!.value),
                                  style: TextStyle(
                                    color: hasTime ? Colors.white : Colors.red,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'TIME REMAINING',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const SizedBox(
                              height: 40,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                const SizedBox(height: 60),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasTime
                          ? Colors.white
                          : Colors.grey[800],
                      foregroundColor: hasTime ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hasTime ? 'CONTINUE TO APP' : 'GO HOME',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          hasTime ? Icons.arrow_forward : Icons.home,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),

                if (!hasTime) ...[
                  const SizedBox(height: 16),
                  Text(
                    'No time remaining. Try again tomorrow!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
