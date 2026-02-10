import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
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

    final timeUntilBonus = _usageTimer?.timeUntilNextBonus ?? Duration.zero;
    final bonusCountdownFormatted =
        _usageTimer?.formatDuration(timeUntilBonus) ?? "0:00";

    final dailyLimitFormatted = _usageTimer?.formatSeconds(_dailyLimitSeconds);

    // Determine colors based on state
    final Color warningColor = (_isTimeLimitExceeded || _isBonusCooldown)
        ? const Color(0xFFF97316) // Orange
        : const Color(0xFFEF4444); // Red

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Close button
                      if (!_isTotalBlock)
                        Align(
                          alignment: Alignment.topRight,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: const Icon(Icons.close, size: 20),
                            onPressed: _closeActivity,
                          ),
                        ),
                      const Spacer(),

                      // Icon
                      Icon(
                        _isBonusCooldown ? Icons.timer : Icons.block,
                        size: 100,
                        color: warningColor,
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
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // App name
                      Text(
                        _appName ?? _blockedPackageName ?? 'Unknown App',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // BONUS COOLDOWN MODE
                      if (_isBonusCooldown) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                label: 'Daily Remaining',
                                value: remainingFormatted,
                                valueColor: const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInfoCard(
                                label: 'Resets In',
                                value:
                                    _usageTimer?.formatDuration(
                                      timeUntilReset,
                                    ) ??
                                    '',
                                valueColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Bonus timer
                        Container(
                          padding: const EdgeInsets.all(24),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withOpacity(0.1),
                            border: Border.all(color: const Color(0xFFF97316)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Next bonus in',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                bonusCountdownFormatted,
                                style: const TextStyle(
                                  fontSize: 48,
                                  color: Color(0xFFF97316), // Orange
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: [FontFeature.tabularFigures()],
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

                      // TIME LIMIT MODE
                      if (_isTimeLimitExceeded && !_isBonusCooldown) ...[
                        Text(
                          'Daily limit: $dailyLimitFormatted',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                label: 'Time Remaining',
                                value: remainingFormatted,
                                valueColor: const Color(0xFFF97316),
                                borderColor: const Color(0xFFF97316),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildInfoCard(
                                label: 'Restored In',
                                value:
                                    _usageTimer?.formatDuration(
                                      timeUntilReset,
                                    ) ??
                                    '',
                                valueColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // NORMAL BLOCK MODE
                      if (!_isTimeLimitExceeded &&
                          !_isBonusCooldown &&
                          !_isTotalBlock) ...[
                        Text(
                          'This app has been blocked.\nYou cannot access it right now.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _launchUnblockedApp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
                        ),
                      ],

                      // WEBSITE / TOTAL BLOCK MODE
                      if (_isTotalBlock) ...[
                        const Text(
                          'Strict blocking is active for this content.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _launchSafeSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search),
                                SizedBox(width: 8),
                                Text(
                                  'Go to Google Search',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _closeActivity,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.home),
                                SizedBox(width: 8),
                                Text('Go to Home Screen'),
                              ],
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
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required Color valueColor,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A), // Dark zinc bg
        border: Border.all(color: borderColor ?? Colors.transparent),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
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
