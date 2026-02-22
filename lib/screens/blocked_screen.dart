import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quit/usage_timer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quit/theme/neon_palette.dart';

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

    // Monochrome shimmer
    final shinyGradient = LinearGradient(
      colors: [
        const Color(0xFFE5E7EB),
        const Color(0xFFFFFFFF),
        const Color(0xFFE5E7EB),
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: const GradientRotation(0.5),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: NeonPalette.bg,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Compact Header
                        if (!_isTotalBlock)
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: NeonPalette.textMuted,
                                size: 20,
                              ),
                              onPressed: _closeActivity,
                            ),
                          ),

                        Icon(
                          _isBonusCooldown ? Icons.timer_outlined : Icons.block,
                          size: 56,
                          color: Colors.white70,
                        ),
                        const SizedBox(height: 12),

                        Text(
                          _isTotalBlock
                              ? 'Access Restricted'
                              : (_isBonusCooldown
                                    ? 'Daily Goal Reached'
                                    : (_isTimeLimitExceeded
                                          ? 'Time Limit Met'
                                          : 'App Restricted')),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: NeonPalette.text,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _appName ?? _blockedPackageName ?? 'Current App',
                          style: TextStyle(
                            fontSize: 14,
                            color: NeonPalette.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 32),

                        // MAIN CONTENT (LOGIC PRESERVED)

                        // BONUS COOLDOWN MODE
                        if (_isBonusCooldown) ...[
                          const Text(
                            'NEXT BONUS IN',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                shinyGradient.createShader(bounds),
                            child: Text(
                              bonusCountdownFormatted,
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontFeatures: [FontFeature.tabularFigures()],
                                letterSpacing: -2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Compact Info Grid
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildCompactInfo(
                                    'DAILY LEFT',
                                    remainingFormatted,
                                    Colors.white,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.white10,
                                ),
                                Expanded(
                                  child: _buildCompactInfo(
                                    'RESETS IN',
                                    _usageTimer?.formatDuration(
                                          timeUntilReset,
                                        ) ??
                                        '',
                                    NeonPalette.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '💡 Bonus time grants 5m of access.',
                            style: TextStyle(
                              color: NeonPalette.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ]
                        // TIME LIMIT MODE
                        else if (_isTimeLimitExceeded) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'DAILY REMAINING',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  remainingFormatted,
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Limit: $dailyLimitFormatted • Resets in ${_usageTimer?.formatDuration(timeUntilReset) ?? ""}',
                            style: TextStyle(
                              color: NeonPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ]
                        // NORMAL BLOCK MODE
                        else if (!_isTotalBlock) ...[
                          const Text(
                            'This app is currently managed.\nPlease check back later.',
                            style: TextStyle(
                              fontSize: 15,
                              color: NeonPalette.textMuted,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          _buildActionButton(
                            label: 'UNBLOCK APP',
                            onPressed: _launchUnblockedApp,
                            color: Colors.white,
                            textColor: Colors.black,
                          ),
                        ],

                        // WEBSITE / TOTAL BLOCK MODE
                        if (_isTotalBlock) ...[
                          const SizedBox(height: 8),
                          _buildActionButton(
                            label: 'GO TO GOOGLE',
                            onPressed: _launchSafeSearch,
                            color: Colors.white,
                            textColor: Colors.black,
                            icon: Icons.search,
                          ),
                          const SizedBox(height: 12),
                          _buildOutlineButton(
                            label: 'BACK TO HOME',
                            onPressed: _closeActivity,
                            icon: Icons.home_outlined,
                          ),
                        ],

                        const SizedBox(height: 24),
                        if (!_isTotalBlock)
                          TextButton(
                            onPressed: _closeActivity,
                            child: const Text(
                              'I\'ll do something else',
                              style: TextStyle(
                                color: NeonPalette.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCompactInfo(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NeonPalette.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
    Color textColor = NeonPalette.text,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String label,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: NeonPalette.text,
          side: const BorderSide(color: NeonPalette.border),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: NeonPalette.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ],
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
