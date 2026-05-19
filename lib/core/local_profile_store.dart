import 'package:shared_preferences/shared_preferences.dart';

class LocalProfileStore {
  LocalProfileStore(this._prefs);

  final SharedPreferences _prefs;

  static const modeKey = 'local_profile_mode';
  static const guestMode = 'guest';
  static const accountMode = 'account';

  static const List<String> _managedIntKeys = [
    'daily_limit_seconds',
    'remaining_seconds',
    'timer_last_reset',
    'used_today_seconds',
    'gambling_lost_today_seconds',
    'last_bonus_time',
    'daily_time_ran_out_timestamp',
    'reset_interval_seconds',
    'bonus_refill_interval_seconds',
    'bonus_amount_seconds',
  ];

  static const List<String> _managedBoolKeys = ['timer_first_choice_made'];

  static const List<String> _managedStringListKeys = [
    'blocked_apps',
    'blocked_websites',
    'custom_website_urls',
  ];

  static const List<String> _managedStringKeys = [
    'sync_last_synced_state_hash',
  ];

  Future<void> ensureActiveMode({required bool guestEnabled}) async {
    final target = guestEnabled ? guestMode : accountMode;
    await switchMode(target);
  }

  Future<void> switchMode(String targetMode) async {
    final currentMode = _prefs.getString(modeKey) ?? accountMode;
    if (currentMode == targetMode) return;

    await _saveCurrentModeSnapshot(currentMode);
    await _clearManagedLiveKeys();
    await _restoreModeSnapshot(targetMode);
    await _prefs.setString(modeKey, targetMode);
  }

  Future<void> _saveCurrentModeSnapshot(String mode) async {
    for (final key in _managedIntKeys) {
      final value = _prefs.getInt(key);
      final scoped = _scopedKey(mode, key);
      if (value == null) {
        await _prefs.remove(scoped);
      } else {
        await _prefs.setInt(scoped, value);
      }
    }

    for (final key in _managedBoolKeys) {
      final value = _prefs.getBool(key);
      final scoped = _scopedKey(mode, key);
      if (value == null) {
        await _prefs.remove(scoped);
      } else {
        await _prefs.setBool(scoped, value);
      }
    }

    for (final key in _managedStringKeys) {
      final value = _prefs.getString(key);
      final scoped = _scopedKey(mode, key);
      if (value == null) {
        await _prefs.remove(scoped);
      } else {
        await _prefs.setString(scoped, value);
      }
    }

    for (final key in _managedStringListKeys) {
      final value = _prefs.getStringList(key);
      final scoped = _scopedKey(mode, key);
      if (value == null) {
        await _prefs.remove(scoped);
      } else {
        await _prefs.setStringList(scoped, value);
      }
    }
  }

  Future<void> _restoreModeSnapshot(String mode) async {
    for (final key in _managedIntKeys) {
      final scoped = _scopedKey(mode, key);
      final value = _prefs.getInt(scoped);
      if (value != null) {
        await _prefs.setInt(key, value);
      }
    }

    for (final key in _managedBoolKeys) {
      final scoped = _scopedKey(mode, key);
      final value = _prefs.getBool(scoped);
      if (value != null) {
        await _prefs.setBool(key, value);
      }
    }

    for (final key in _managedStringKeys) {
      final scoped = _scopedKey(mode, key);
      final value = _prefs.getString(scoped);
      if (value != null) {
        await _prefs.setString(key, value);
      }
    }

    for (final key in _managedStringListKeys) {
      final scoped = _scopedKey(mode, key);
      final value = _prefs.getStringList(scoped);
      if (value != null) {
        await _prefs.setStringList(key, value);
      }
    }
  }

  Future<void> _clearManagedLiveKeys() async {
    for (final key in _managedIntKeys) {
      await _prefs.remove(key);
    }
    for (final key in _managedBoolKeys) {
      await _prefs.remove(key);
    }
    for (final key in _managedStringKeys) {
      await _prefs.remove(key);
    }
    for (final key in _managedStringListKeys) {
      await _prefs.remove(key);
    }
  }

  String _scopedKey(String mode, String key) => 'profile_${mode}_$key';
}
