import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet_snapshot.dart';
import 'wallet_service.dart';
import 'wallet_sync_keys.dart';

class SyncService {
  SyncService(this._walletService, this._prefs);

  final WalletService _walletService;
  final SharedPreferences _prefs;

  static const _kPendingDelta = WalletSyncKeys.pendingDelta;
  static const _kLastSyncMs = WalletSyncKeys.lastSyncMs;
  static const _kWalletVersion = WalletSyncKeys.walletVersion;
  static const _kLastSyncedRemaining = WalletSyncKeys.lastSyncedRemaining;
  static const _kLastSyncedStateHash = WalletSyncKeys.lastSyncedStateHash;

  int get pendingUsageDelta => _prefs.getInt(_kPendingDelta) ?? 0;

  Future<void> addLocalUsageDelta(int seconds) async {
    final next = pendingUsageDelta + seconds;
    await _prefs.setInt(_kPendingDelta, next);
  }

  Future<WalletSnapshot> syncWalletIfDirty() async {
    final remaining = _prefs.getInt('remaining_seconds') ?? 0;
    final dailyLimit = _prefs.getInt('daily_limit_seconds') ?? 0;
    final resetInterval = _prefs.getInt('reset_interval_seconds') ?? 86400;
    final resetAnchorMs = _prefs.getInt('timer_last_reset') ?? 0;
    final bonusRefillInterval =
        _prefs.getInt('bonus_refill_interval_seconds') ?? 3600;
    final bonusAmount = _prefs.getInt('bonus_amount_seconds') ?? 300;
    final lastBonusMs = _prefs.getInt('last_bonus_time') ?? 0;
    final dailyTimeRanOutMs =
        _prefs.getInt('daily_time_ran_out_timestamp') ?? 0;
    final stateHash = [
      remaining,
      dailyLimit,
      resetInterval,
      resetAnchorMs,
      bonusRefillInterval,
      bonusAmount,
      lastBonusMs,
      dailyTimeRanOutMs,
    ].join(':');
    final lastSyncedStateHash = _prefs.getString(_kLastSyncedStateHash);

    WalletSnapshot wallet;
    if (lastSyncedStateHash == null || lastSyncedStateHash != stateHash) {
      wallet = await _walletService.setWalletState(
        balanceSeconds: remaining,
        dailyLimitSeconds: dailyLimit,
        resetIntervalSeconds: resetInterval,
        resetAnchorMs: resetAnchorMs,
        bonusRefillIntervalSeconds: bonusRefillInterval,
        bonusAmountSeconds: bonusAmount,
        lastBonusMs: lastBonusMs,
        dailyTimeRanOutMs: dailyTimeRanOutMs,
      );
      await _prefs.setInt(_kLastSyncedRemaining, remaining);
      await _prefs.setString(_kLastSyncedStateHash, stateHash);
    } else {
      wallet = await _walletService.getWallet();
    }

    await _prefs.setInt(_kLastSyncMs, DateTime.now().millisecondsSinceEpoch);
    await _prefs.setInt(_kWalletVersion, wallet.version);
    if (pendingUsageDelta != 0) {
      await _prefs.setInt(_kPendingDelta, 0);
    }
    return wallet;
  }

  Future<void> forceSync() async {
    await syncWalletIfDirty();
  }
}
