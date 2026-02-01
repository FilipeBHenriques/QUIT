import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quit/usage_timer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  static const blockedAppChannel = MethodChannel('com.quit.app/blocked_app');
  static const navigationChannel = MethodChannel('com.quit.app/navigation');
  static const monitoringChannel = MethodChannel('com.quit.app/monitoring');

  String? _blockedPackageName;
  String? _appName;
  bool _loading = true;
  bool _isTimeLimitExceeded = false;
  int _dailyLimitSeconds = 0;
  int _initialRemainingSeconds = 0;
  bool _isBonusCooldown = false;
  int _timeUntilBonusSeconds = 0;
  bool _isTotalBlock = false;

  UsageTimer? _usageTimer;

  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
    _loadBlockedAppInfo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Update UI every second for real-time countdown
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (mounted && _usageTimer != null) {
        await _usageTimer!.reload();
        setState(() {
          // Check daily reset
          if (_usageTimer!.shouldReset()) {
            _handleTimerReset();
            return;
          }
          
          // Check if bonus cooldown just finished
          if (_isBonusCooldown && _usageTimer!.timeUntilNextBonus == null) {
            print('🎁 Bonus cooldown finished - relaunching app');
            _retryLaunchApp();
          }
        });
      }
    });
  }

  Future<void> _initializeTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _usageTimer = UsageTimer(prefs);
    await _usageTimer?.checkAndResetIfNeeded();
  }



  Future<void> _loadBlockedAppInfo() async {
    try {
      final info = await blockedAppChannel.invokeMethod('getBlockedAppInfo');
      final packageName = info['packageName'] as String?;
      final appName = info['appName'] as String?;
      final timeLimit = info['timeLimit'] as bool? ?? false;
      final dailyLimit = info['dailyLimitSeconds'] as int? ?? 0;
      final remaining = info['remainingSeconds'] as int? ?? 0;

      final bonusCooldown = info['bonusCooldown'] as bool? ?? false;
      final timeUntilBonusMs = info['timeUntilBonusMs'] as int? ?? 0;

      setState(() {
        _blockedPackageName = packageName;
        _appName = appName ?? packageName;
        _isTimeLimitExceeded = timeLimit;
        _dailyLimitSeconds = dailyLimit;
        _initialRemainingSeconds = remaining;
        _isBonusCooldown = bonusCooldown;
        _timeUntilBonusSeconds = (timeUntilBonusMs / 1000).round();
        _isTotalBlock = info['totalBlock'] as bool? ?? false;

        _loading = false;
      });

      print(
        '📦 Blocked: $packageName (limit: $dailyLimit s, remaining: $remaining s, bonusCooldown: $bonusCooldown)',
      );
    } catch (e) {
      print('❌ Error loading blocked app info: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _handleTimerReset() async {
    print('🔄 Timer reset detected - closing blocking screen');
    _closeActivity();
  }

  Future<void> _launchUnblockedApp() async {
    if (_blockedPackageName == null) {
      _closeActivity();
      return;
    }

    print('🚀 Unblocking and launching: $_blockedPackageName');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
    blockedApps.remove(_blockedPackageName);
    await prefs.setStringList('blocked_apps', blockedApps);

    try {
      await monitoringChannel.invokeMethod('updateBlockedApps', {
        'blockedApps': blockedApps,
      });
    } catch (e) {
      print('⚠️ Error updating monitoring: $e');
    }

    try {
      await navigationChannel.invokeMethod('launchApp', {
        'packageName': _blockedPackageName,
      });
    } catch (e) {
      print('❌ Error launching app: $e');
      _closeActivity();
    }
  }

  bool _isRedirecting = false;

  Future<void> _launchSafeSearch() async {
    if (_isRedirecting) return;
    setState(() => _isRedirecting = true);

    try {
      await navigationChannel.invokeMethod('launchUrl', {
        'url': 'https://www.google.com',
      });
    } catch (e) {
      print('❌ Error launching safe search: $e');
      _closeActivity();
    }
  }

  Future<void> _retryLaunchApp() async {
    if (_blockedPackageName == null || _isRedirecting) {
      if (_blockedPackageName == null) _closeActivity();
      return;
    }
    
    _isRedirecting = true;
    print('🔁 Bonus ready - relaunching: $_blockedPackageName');
    
    try {
      await navigationChannel.invokeMethod('launchApp', {
        'packageName': _blockedPackageName,
      });
      // Don't flip _isRedirecting back immediately to prevent race conditions in the timer loop
    } catch (e) {
      print('❌ Error relaunching app: $e');
      _closeActivity();
    }
  }

  Future<void> _closeActivity() async {
    print('🔴 Closing blocked screen - going home');
    try {
      await navigationChannel.invokeMethod('goHome');
    } catch (e) {
      print('❌ Error going home: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeUntilReset = _usageTimer?.timeUntilReset() ?? Duration.zero;
    final remainingFormatted = _usageTimer?.remainingFormatted ?? "0:00";
    
    // Calculate bonus countdown directly from usage timer
    // If null (meaning ready or not started), show 0:00
    final timeUntilBonus = _usageTimer?.timeUntilNextBonus ?? Duration.zero;
    final bonusCountdownFormatted = _usageTimer?.formatDuration(timeUntilBonus) ?? "0:00";

    final dailyLimitFormatted = _usageTimer?.formatSeconds(_dailyLimitSeconds);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Close button (only show if not total block, otherwise user must go home via system)
                        // Actually, user should always be able to go home, but we'll label it "Go Home" or keep X
                        if (!_isTotalBlock)
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 32,
                              ),
                              onPressed: _closeActivity,
                            ),
                          ),
                        const Spacer(),

                        // Icon
                        Icon(
                          _isBonusCooldown ? Icons.timer_outlined : Icons.block,
                          size: 100,
                          color: _isTimeLimitExceeded || _isBonusCooldown
                              ? Colors.orange
                              : Colors.red,
                        ),
                        const SizedBox(height: 32),

                        Text(
                          _isTotalBlock
                              ? 'Website Blocked!'
                              : (_isBonusCooldown
                                  ? 'Daily Time Exhausted'
                                  : (_isTimeLimitExceeded
                                        ? 'Time Limit Reached!'
                                        : 'App Blocked!')),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // App name
                        Text(
                          _appName ?? _blockedPackageName ?? 'Unknown App',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        // BONUS COOLDOWN MODE - Show both daily timer (0:00) and bonus timer
                        if (_isBonusCooldown) ...[
                          // Daily timer (exhausted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red, width: 2),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Daily Time Remaining',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  remainingFormatted,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Daily reset countdown
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Daily Limit Resets In',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _usageTimer?.formatDuration(timeUntilReset) ??
                                      '',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Bonus timer
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.orange[900],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Next bonus in',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  bonusCountdownFormatted,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '💡 You get 5 bonus minutes every hour',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // TIME LIMIT MODE (daily time available but exhausted)
                        if (_isTimeLimitExceeded && !_isBonusCooldown) ...[
                          // Daily limit info
                          Text(
                            'Daily limit: $dailyLimitFormatted',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Remaining time display (should be 0:00)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Time Remaining',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  remainingFormatted,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Countdown to reset
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Access Restored In',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _usageTimer?.formatDuration(timeUntilReset) ??
                                      '',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // NORMAL BLOCK MODE (no timer)
                        if (!_isTimeLimitExceeded && !_isBonusCooldown && !_isTotalBlock) ...[
                          const Text(
                            'This app has been blocked.\nYou cannot access it right now.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white60,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 48),

                          ElevatedButton(
                            onPressed: _launchUnblockedApp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            child: const Text(
                              'Unblock This App',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],

                        // WEBSITE / TOTAL BLOCK MODE
                        if (_isTotalBlock) ...[
                          const Text(
                            'Strict blocking is active for this content.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 48),
                          ElevatedButton.icon(
                            onPressed: _launchSafeSearch,
                            icon: const Icon(Icons.search),
                            label: const Text(
                              'Go to Google Search',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _closeActivity,
                            icon: const Icon(Icons.home, color: Colors.white60),
                            label: const Text(
                              'Go to Home Screen',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }
}
