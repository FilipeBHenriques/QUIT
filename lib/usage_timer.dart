// lib/models/usage_timer.dart

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class UsageTimer {
  static const String _keyDailyLimit = 'daily_limit_seconds';
  static const String _keyRemaining = 'remaining_seconds';
  static const String _keyLastReset = 'timer_last_reset';
  static const String _keySessionStart = 'current_session_start';
  static const String _keyUsedToday = 'used_today_seconds';
  static const String _keyLastBonus = 'last_bonus_time';
  static const String _keyDailyTimeRanOut = 'daily_time_ran_out_timestamp';

  final SharedPreferences _prefs;

  /// Duration between resets (default: 24 hours). You can adjust this to whatever you want.
  Duration resetInterval;

  /// Duration between bonus refills (default: 1 hour).
  Duration bonusRefillInterval;

  UsageTimer(
    this._prefs, {
    this.resetInterval = const Duration(hours: 24, minutes: 0, seconds: 0),
    this.bonusRefillInterval = const Duration(hours: 1, minutes: 0, seconds: 0),
  }) {
    // Save reset interval to preferences so MonitoringService can read it
    _prefs.setInt('reset_interval_seconds', resetInterval.inSeconds);
    // Save bonus refill interval to preferences so MonitoringService can read it
    _prefs.setInt(
      'bonus_refill_interval_seconds',
      bonusRefillInterval.inSeconds,
    );
    // Initialize bonus amount if not set (default: 5 minutes)
    if (!_prefs.containsKey('bonus_amount_seconds')) {
      _prefs.setInt('bonus_amount_seconds', 300); // 5 minutes
    }
  }

  // Configuration
  int get dailyLimitSeconds => _prefs.getInt(_keyDailyLimit) ?? 0;

  Future<void> setDailyLimit(int seconds) async {
    // Get actual used time from persistent storage (NOT calculated)
    final usedToday = _prefs.getInt(_keyUsedToday) ?? 0;

    // Set new limit
    await _prefs.setInt(_keyDailyLimit, seconds);

    // Calculate new remaining based on actual used time
    if (seconds == 0) {
      // Disabling: set remaining to 0
      await _prefs.setInt(_keyRemaining, 0);
      await _prefs.remove(_keyDailyTimeRanOut); // Clear the ran out timestamp
    } else {
      // Enabling/changing: remaining = newLimit - actualUsedTime
      final newRemaining = max(0, seconds - usedToday);
      await _prefs.setInt(_keyRemaining, newRemaining);

      // If remaining is already 0, mark that daily time has run out
      if (newRemaining == 0) {
        await _prefs.setInt(
          _keyDailyTimeRanOut,
          DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        await _prefs.remove(_keyDailyTimeRanOut);
      }
    }

    // ✨ INITIALIZE BONUS SYSTEM
    if (!_prefs.containsKey(_keyLastBonus)) {
      await _prefs.setInt(_keyLastBonus, 0); // 0 = never granted
      print('✨ Bonus system initialized (never granted)');
    }

    // DON'T set reset timestamp here - it will be set on first app usage
    // This way the countdown only starts when user actually uses a blocked app

    print(
      '⏰ Limit: ${seconds}s, Used: ${usedToday}s, Remaining: ${remainingSeconds}s',
    );
  }

  // State
  int get remainingSeconds => _prefs.getInt(_keyRemaining) ?? 0;

  // Derived: time used today
  int get usedSeconds => max(0, dailyLimitSeconds - remainingSeconds);

  Future<void> _setRemainingSeconds(int seconds) async {
    await _prefs.setInt(_keyRemaining, max(0, seconds));
  }

  int get lastResetTimestamp => _prefs.getInt(_keyLastReset) ?? 0;

  // ✨ NEW: Daily time ran out timestamp
  int get dailyTimeRanOutTimestamp => _prefs.getInt(_keyDailyTimeRanOut) ?? 0;

  // ✨ BONUS TIME GETTERS - Modified to only start after daily time runs out
  int get lastBonusTimestamp => _prefs.getInt(_keyLastBonus) ?? 0;

  bool get hasBonusAvailable {
    // Bonus is only available if daily time has run out
    if (dailyTimeRanOutTimestamp == 0) return false;

    final lastBonus = lastBonusTimestamp;

    // If never granted, bonus is available immediately after daily time runs out
    if (lastBonus == 0) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    final bonusIntervalMs = bonusRefillInterval.inMilliseconds;

    // Check if enough time has passed since last bonus
    return (now - lastBonus) >= bonusIntervalMs;
  }

  Duration? get timeUntilNextBonus {
    // If daily time hasn't run out yet, no bonus timer
    if (dailyTimeRanOutTimestamp == 0) return null;

    final lastBonus = lastBonusTimestamp;
    final bonusIntervalMs = bonusRefillInterval.inMilliseconds;

    // If never granted, calculate time since daily ran out
    if (lastBonus == 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final timeSinceDailyRanOut = now - dailyTimeRanOutTimestamp;

      if (timeSinceDailyRanOut >= bonusIntervalMs) {
        return null; // Bonus available now
      }

      return Duration(milliseconds: bonusIntervalMs - timeSinceDailyRanOut);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastBonus;

    if (elapsed >= bonusIntervalMs) return null; // Available now

    return Duration(milliseconds: bonusIntervalMs - elapsed);
  }

  // Mark that daily time has run out (called by MonitoringService when remaining hits 0)
  Future<void> markDailyTimeRanOut() async {
    if (dailyTimeRanOutTimestamp == 0) {
      await _prefs.setInt(
        _keyDailyTimeRanOut,
        DateTime.now().millisecondsSinceEpoch,
      );
      print('⏰ Daily time ran out - bonus timer started');
    }
  }

  // Reset logic
  bool shouldReset() {
    if (lastResetTimestamp == 0) return false;

    final lastReset = DateTime.fromMillisecondsSinceEpoch(lastResetTimestamp);
    final now = DateTime.now();
    final difference = now.difference(lastReset);

    return difference >= resetInterval;
  }

  Future<void> resetTimer() async {
    await _prefs.setInt(_keyRemaining, dailyLimitSeconds);
    await _prefs.setInt(_keyUsedToday, 0); // Reset used time
    await _prefs.remove(_keyLastReset); // Clear timestamp - wait for next usage
    await _prefs.remove(_keyDailyTimeRanOut); // Clear daily ran out timestamp
    await _prefs.remove(
      'timer_first_choice_made',
    ); // Reset choice flag to show gamble screen again
    // NOTE: Don't reset _keyLastBonus - it's independent
    print('⏰ Timer reset: ${dailyLimitSeconds}s available, countdown cleared');
  }

  Future<void> checkAndResetIfNeeded() async {
    if (shouldReset()) {
      await resetTimer();
    }
  }

  // Time until next reset
  Duration timeUntilReset() {
    if (lastResetTimestamp == 0) {
      // No reset timestamp yet - show "Not started" or infinity
      return Duration.zero;
    }

    final lastReset = DateTime.fromMillisecondsSinceEpoch(lastResetTimestamp);
    final nextReset = lastReset.add(resetInterval);
    final now = DateTime.now();

    return nextReset.difference(now).isNegative
        ? Duration.zero
        : nextReset.difference(now);
  }

  // Calculate time used today
  int get usedTodaySeconds {
    return _prefs.getInt(_keyUsedToday) ?? 0;
  }

  // Format MM:SS
  String formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // Format HH:MM:SS or MM:SS
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String formatTimeUntilReset() {
    if (lastResetTimestamp == 0) {
      return 'Not started';
    }
    return formatDuration(timeUntilReset());
  }

  // Get remaining as formatted string
  String get remainingFormatted => formatSeconds(remainingSeconds);

  // Get used today as formatted string
  String get usedTodayFormatted => formatSeconds(usedTodaySeconds);

  // Reload from SharedPreferences (for polling)
  Future<void> reload() async {
    await _prefs.reload();
  }

  // Format seconds as MM:SS (deprecated, use formatSeconds)
  static String formatMinutesSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
