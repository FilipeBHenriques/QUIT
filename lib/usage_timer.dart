// lib/models/usage_timer.dart

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class UsageTimer {
  static const String _keyDailyLimit = 'daily_limit_seconds';
  static const String _keyRemaining = 'remaining_seconds';
  static const String _keyLastReset = 'timer_last_reset';
  static const String _keySessionStart = 'current_session_start';
  static const String _keyUsedToday = 'used_today_seconds';

  final SharedPreferences _prefs;

  /// Duration between resets (default: 24 hours). You can adjust this to whatever you want.
  Duration resetInterval;

  UsageTimer(
    this._prefs, {
    this.resetInterval = const Duration(hours: 24, minutes: 0, seconds: 0),
  });

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
    } else {
      // Enabling/changing: remaining = newLimit - actualUsedTime
      final newRemaining = max(0, seconds - usedToday);
      await _prefs.setInt(_keyRemaining, newRemaining);
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
    print('⏰ Timer reset: ${dailyLimitSeconds}s available, countdown cleared');
  }

  Future<void> checkAndResetIfNeeded() async {
    if (shouldReset()) {
      await resetTimer();
    }
  }

  // Time tracking
  Future<void> decrementTime(int seconds) async {
    final current = remainingSeconds;
    await _setRemainingSeconds(current - seconds);
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
