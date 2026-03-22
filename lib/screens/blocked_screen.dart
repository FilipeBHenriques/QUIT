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

class _BlockedScreenState extends State<BlockedScreen>
    with TickerProviderStateMixin {
  static const blockedAppChannel = MethodChannel('com.quit.app/blocked_app');
  static const navigationChannel = MethodChannel('com.quit.app/navigation');
  static const monitoringChannel = MethodChannel('com.quit.app/monitoring');

  String? _blockedPackageName;
  String? _appName;
  bool _loading = true;
  bool _isTimeLimitExceeded = false;
  int _dailyLimitSeconds = 0;
  bool _isBonusCooldown = false;
  bool _isTotalBlock = false;
  bool _isRedirecting = false;

  UsageTimer? _usageTimer;
  Timer? _updateTimer;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _initializeTimer();
    _loadBlockedAppInfo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (mounted && _usageTimer != null) {
        await _usageTimer!.reload();
        setState(() {
          if (_usageTimer!.shouldReset()) {
            _handleTimerReset();
            return;
          }
          if (_isBonusCooldown && _usageTimer!.timeUntilNextBonus == null) {
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
      final bonusCooldown = info['bonusCooldown'] as bool? ?? false;

      setState(() {
        _blockedPackageName = packageName;
        _appName = appName ?? packageName;
        _isTimeLimitExceeded = timeLimit;
        _dailyLimitSeconds = dailyLimit;
        _isBonusCooldown = bonusCooldown;
        _isTotalBlock = info['totalBlock'] as bool? ?? false;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleTimerReset() async => _closeActivity();

  Future<void> _launchUnblockedApp() async {
    if (_blockedPackageName == null) {
      _closeActivity();
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
    blockedApps.remove(_blockedPackageName);
    await prefs.setStringList('blocked_apps', blockedApps);

    try {
      await monitoringChannel.invokeMethod('updateBlockedApps', {
        'blockedApps': blockedApps,
      });
    } catch (_) {}

    try {
      await navigationChannel.invokeMethod('launchApp', {
        'packageName': _blockedPackageName,
      });
    } catch (_) {
      _closeActivity();
    }
  }

  Future<void> _launchSafeSearch() async {
    if (_isRedirecting) return;
    setState(() => _isRedirecting = true);
    try {
      await navigationChannel.invokeMethod('launchUrl', {
        'url': 'https://www.google.com',
      });
    } catch (_) {
      _closeActivity();
    }
  }

  Future<void> _retryLaunchApp() async {
    if (_blockedPackageName == null || _isRedirecting) {
      if (_blockedPackageName == null) _closeActivity();
      return;
    }
    _isRedirecting = true;
    try {
      await navigationChannel.invokeMethod('launchApp', {
        'packageName': _blockedPackageName,
      });
    } catch (_) {
      _closeActivity();
    }
  }

  Future<void> _closeActivity() async {
    try {
      await navigationChannel.invokeMethod('goHome');
    } catch (_) {}
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeUntilReset = _usageTimer?.timeUntilReset() ?? Duration.zero;
    final remainingFormatted = _usageTimer?.remainingFormatted ?? '0:00';
    final timeUntilBonus = _usageTimer?.timeUntilNextBonus ?? Duration.zero;
    final bonusCountdownFormatted =
        _usageTimer?.formatDuration(timeUntilBonus) ?? '0:00';
    final dailyLimitFormatted =
        _usageTimer?.formatSeconds(_dailyLimitSeconds) ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: NeonPalette.bg,
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: NeonPalette.violet,
                  strokeWidth: 1.5,
                ),
              )
            : SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top row
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _closeActivity,
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

                        // Block icon
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final t = _pulseController.value;
                            final iconColor = _isTotalBlock
                                ? NeonPalette.rose
                                : (_isBonusCooldown
                                      ? NeonPalette.amber
                                      : NeonPalette.textMuted);
                            return Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: iconColor.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: iconColor.withValues(
                                    alpha: 0.18 + t * 0.18,
                                  ),
                                  width: 0.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: iconColor.withValues(
                                      alpha: 0.10 + t * 0.12,
                                    ),
                                    blurRadius: 24,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isBonusCooldown
                                    ? Icons.timer_outlined
                                    : Icons.block_rounded,
                                size: 30,
                                color: iconColor.withValues(alpha: 0.7 + t * 0.3),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Title
                        Text(
                          _isTotalBlock
                              ? 'Access Restricted'
                              : (_isBonusCooldown
                                    ? 'Daily Goal Reached'
                                    : (_isTimeLimitExceeded
                                          ? 'Time Limit Met'
                                          : 'App Restricted')),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: NeonPalette.text,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 6),

                        Text(
                          _appName ?? _blockedPackageName ?? 'Current App',
                          style: const TextStyle(
                            fontSize: 13,
                            color: NeonPalette.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 40),

                        // ── BONUS COOLDOWN ──
                        if (_isBonusCooldown) ...[
                          const Text(
                            'NEXT BONUS IN',
                            style: TextStyle(
                              color: NeonPalette.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFFFFAB00),
                                Color(0xFFFFF3CD),
                                Color(0xFFFFAB00),
                              ],
                            ).createShader(bounds),
                            child: Text(
                              bonusCountdownFormatted,
                              style: const TextStyle(
                                fontSize: 68,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -2,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: NeonPalette.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: NeonPalette.border,
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _InfoCell(
                                    label: 'DAILY LEFT',
                                    value: remainingFormatted,
                                  ),
                                ),
                                Container(
                                  width: 0.5,
                                  height: 28,
                                  color: NeonPalette.border,
                                ),
                                Expanded(
                                  child: _InfoCell(
                                    label: 'RESETS IN',
                                    value: _usageTimer?.formatDuration(
                                          timeUntilReset,
                                        ) ??
                                        '',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Bonus time grants 5 minutes of access.',
                            style: TextStyle(
                              color: NeonPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ]

                        // ── TIME LIMIT ──
                        else if (_isTimeLimitExceeded) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 24,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: NeonPalette.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: NeonPalette.border,
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'DAILY REMAINING',
                                  style: TextStyle(
                                    color: NeonPalette.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  remainingFormatted,
                                  style: const TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    color: NeonPalette.text,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Limit: $dailyLimitFormatted  ·  Resets in ${_usageTimer?.formatDuration(timeUntilReset) ?? ""}',
                            style: const TextStyle(
                              color: NeonPalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ]

                        // ── NORMAL BLOCK ──
                        else if (!_isTotalBlock) ...[
                          const Text(
                            'This app is currently managed.\nCheck back later.',
                            style: TextStyle(
                              fontSize: 15,
                              color: NeonPalette.textMuted,
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          _ActionButton(
                            label: 'UNBLOCK APP',
                            onPressed: _launchUnblockedApp,
                            filled: true,
                          ),
                        ],

                        // ── TOTAL BLOCK ──
                        if (_isTotalBlock) ...[
                          const SizedBox(height: 8),
                          _ActionButton(
                            label: 'GO TO GOOGLE',
                            onPressed: _launchSafeSearch,
                            filled: true,
                            icon: Icons.search_rounded,
                          ),
                          const SizedBox(height: 10),
                          _ActionButton(
                            label: 'BACK TO HOME',
                            onPressed: _closeActivity,
                            filled: false,
                            icon: Icons.home_outlined,
                          ),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: NeonPalette.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: NeonPalette.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final IconData? icon;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
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
                    Icon(icon, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: NeonPalette.text,
                side: const BorderSide(color: NeonPalette.border, width: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: NeonPalette.textMuted),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
