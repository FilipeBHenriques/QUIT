import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimerState {
  const TimerState({
    required this.remainingSeconds,
    required this.dailyLimitSeconds,
    required this.bonusAvailable,
    required this.lastTickAt,
    required this.dirty,
  });

  final int remainingSeconds;
  final int dailyLimitSeconds;
  final bool bonusAvailable;
  final DateTime lastTickAt;
  final bool dirty;

  TimerState copyWith({
    int? remainingSeconds,
    int? dailyLimitSeconds,
    bool? bonusAvailable,
    DateTime? lastTickAt,
    bool? dirty,
  }) {
    return TimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      dailyLimitSeconds: dailyLimitSeconds ?? this.dailyLimitSeconds,
      bonusAvailable: bonusAvailable ?? this.bonusAvailable,
      lastTickAt: lastTickAt ?? this.lastTickAt,
      dirty: dirty ?? this.dirty,
    );
  }
}

class TimerStateController extends ValueNotifier<TimerState> {
  TimerStateController(this._prefs)
      : super(
          TimerState(
            remainingSeconds: _prefs.getInt('remaining_seconds') ?? 0,
            dailyLimitSeconds: _prefs.getInt('daily_limit_seconds') ?? 0,
            bonusAvailable: false,
            lastTickAt: DateTime.now(),
            dirty: false,
          ),
        ) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final SharedPreferences _prefs;
  Timer? _ticker;

  void _tick() {
    value = value.copyWith(lastTickAt: DateTime.now());
  }

  Future<void> loadFromStorage() async {
    final next = value.copyWith(
      remainingSeconds: _prefs.getInt('remaining_seconds') ?? value.remainingSeconds,
      dailyLimitSeconds: _prefs.getInt('daily_limit_seconds') ?? value.dailyLimitSeconds,
      bonusAvailable: (_prefs.getInt('daily_time_ran_out_timestamp') ?? 0) > 0,
      dirty: false,
    );
    value = next;
  }

  Future<void> applyLocalRemaining(int remaining) async {
    final safe = remaining < 0 ? 0 : remaining;
    if (safe == value.remainingSeconds) return;

    value = value.copyWith(remainingSeconds: safe, dirty: true);
    await _prefs.setInt('remaining_seconds', safe);
  }

  Future<void> setDailyLimit(int seconds) async {
    value = value.copyWith(dailyLimitSeconds: seconds, dirty: true);
    await _prefs.setInt('daily_limit_seconds', seconds);
  }

  Future<void> markSynced() async {
    value = value.copyWith(dirty: false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
