import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallet_snapshot.dart';
import 'wallet_sync_keys.dart';

class CloudStateService {
  CloudStateService(this._client);

  final SupabaseClient _client;
  static const _monitoringChannel = MethodChannel('com.quit.app/monitoring');

  Future<void> hydrateLocalCacheFromCloud() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();

    try {
      final walletRow = await _client
          .from('time_wallets')
          .select(
            'user_id,updated_at,version,'
            'balance_seconds,daily_limit_seconds,reset_interval_seconds,'
            'reset_anchor_at,bonus_refill_interval_seconds,bonus_amount_seconds,'
            'last_bonus_at,daily_time_ran_out_at',
          )
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (walletRow != null) {
        final cloud = WalletSnapshot.fromJson((walletRow as Map).cast<String, dynamic>());
        final localStateHash = _localStateHash(prefs);
        final cloudStateHash = _walletStateHashFromSnapshot(cloud);
        final lastSyncedStateHash = prefs.getString(WalletSyncKeys.lastSyncedStateHash);
        final localDirty =
            (lastSyncedStateHash != null && localStateHash != lastSyncedStateHash) ||
            (lastSyncedStateHash == null &&
                localStateHash != cloudStateHash &&
                _localRecencyMs(prefs) > _cloudRecencyMs(cloud));

        if (localDirty) {
          final merged = await _pushLocalWalletToCloudAndFetch(prefs);
          await _applyWalletSnapshotToLocal(prefs, merged);
          await _storeSyncMetadata(prefs, merged);
        } else {
          await _applyWalletSnapshotToLocal(prefs, cloud);
          await _storeSyncMetadata(prefs, cloud);
        }
      }
    } catch (_) {}

    try {
      final blockRow = await _client
          .from('user_blocklists')
          .select('blocked_apps,blocked_websites,custom_websites')
          .eq('user_id', uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (blockRow != null) {
        final blockedApps = ((blockRow['blocked_apps'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList();
        final blockedWebsites =
            ((blockRow['blocked_websites'] as List?) ?? const <dynamic>[])
                .map((e) => e.toString())
                .toList();
        final customWebsites =
            ((blockRow['custom_websites'] as List?) ?? const <dynamic>[])
                .map((e) => e.toString())
                .toList();

        await prefs.setStringList('blocked_apps', blockedApps);
        await prefs.setStringList('blocked_websites', blockedWebsites);
        await prefs.setStringList('custom_website_urls', customWebsites);
      }
    } catch (_) {}

    await _applyMonitoringFromLocalCache(prefs);
  }

  String _walletStateHashFromSnapshot(WalletSnapshot wallet) {
    return [
      wallet.balanceSeconds,
      wallet.dailyLimitSeconds,
      wallet.resetIntervalSeconds,
      wallet.resetAnchorAt?.millisecondsSinceEpoch ?? 0,
      wallet.bonusRefillIntervalSeconds,
      wallet.bonusAmountSeconds,
      wallet.lastBonusAt?.millisecondsSinceEpoch ?? 0,
      wallet.dailyTimeRanOutAt?.millisecondsSinceEpoch ?? 0,
    ].join(':');
  }

  int _localRecencyMs(SharedPreferences prefs) {
    final reset = prefs.getInt('timer_last_reset') ?? 0;
    final bonus = prefs.getInt('last_bonus_time') ?? 0;
    final ranOut = prefs.getInt('daily_time_ran_out_timestamp') ?? 0;
    return [reset, bonus, ranOut].reduce((a, b) => a > b ? a : b);
  }

  int _cloudRecencyMs(WalletSnapshot wallet) {
    final reset = wallet.resetAnchorAt?.millisecondsSinceEpoch ?? 0;
    final bonus = wallet.lastBonusAt?.millisecondsSinceEpoch ?? 0;
    final ranOut = wallet.dailyTimeRanOutAt?.millisecondsSinceEpoch ?? 0;
    return [reset, bonus, ranOut].reduce((a, b) => a > b ? a : b);
  }

  String _localStateHash(SharedPreferences prefs) {
    final remaining = prefs.getInt('remaining_seconds') ?? 0;
    final dailyLimit = prefs.getInt('daily_limit_seconds') ?? 0;
    final resetInterval = prefs.getInt('reset_interval_seconds') ?? 86400;
    final resetAnchorMs = prefs.getInt('timer_last_reset') ?? 0;
    final bonusRefillInterval =
        prefs.getInt('bonus_refill_interval_seconds') ?? 3600;
    final bonusAmount = prefs.getInt('bonus_amount_seconds') ?? 300;
    final lastBonusMs = prefs.getInt('last_bonus_time') ?? 0;
    final dailyTimeRanOutMs =
        prefs.getInt('daily_time_ran_out_timestamp') ?? 0;
    return [
      remaining,
      dailyLimit,
      resetInterval,
      resetAnchorMs,
      bonusRefillInterval,
      bonusAmount,
      lastBonusMs,
      dailyTimeRanOutMs,
    ].join(':');
  }

  Future<WalletSnapshot> _pushLocalWalletToCloudAndFetch(
    SharedPreferences prefs,
  ) async {
    final result = await _client.rpc('set_wallet_state', params: {
      'p_balance_seconds': prefs.getInt('remaining_seconds') ?? 0,
      'p_daily_limit_seconds': prefs.getInt('daily_limit_seconds') ?? 0,
      'p_reset_interval_seconds': prefs.getInt('reset_interval_seconds') ?? 86400,
      'p_reset_anchor_ms': prefs.getInt('timer_last_reset') ?? 0,
      'p_bonus_refill_interval_seconds': prefs.getInt('bonus_refill_interval_seconds') ?? 3600,
      'p_bonus_amount_seconds': prefs.getInt('bonus_amount_seconds') ?? 300,
      'p_last_bonus_ms': prefs.getInt('last_bonus_time') ?? 0,
      'p_daily_time_ran_out_ms': prefs.getInt('daily_time_ran_out_timestamp') ?? 0,
    }).timeout(const Duration(seconds: 4));
    return WalletSnapshot.fromJson((result as Map).cast<String, dynamic>());
  }

  Future<void> _applyWalletSnapshotToLocal(
    SharedPreferences prefs,
    WalletSnapshot wallet,
  ) async {
    await prefs.setInt('remaining_seconds', wallet.balanceSeconds);
    await prefs.setInt('daily_limit_seconds', wallet.dailyLimitSeconds);
    await prefs.setInt('reset_interval_seconds', wallet.resetIntervalSeconds);
    await prefs.setInt(
      'timer_last_reset',
      wallet.resetAnchorAt?.millisecondsSinceEpoch ?? 0,
    );
    await prefs.setInt(
      'bonus_refill_interval_seconds',
      wallet.bonusRefillIntervalSeconds,
    );
    await prefs.setInt('bonus_amount_seconds', wallet.bonusAmountSeconds);
    await prefs.setInt(
      'last_bonus_time',
      wallet.lastBonusAt?.millisecondsSinceEpoch ?? 0,
    );
    await prefs.setInt(
      'daily_time_ran_out_timestamp',
      wallet.dailyTimeRanOutAt?.millisecondsSinceEpoch ?? 0,
    );
  }

  Future<void> _storeSyncMetadata(
    SharedPreferences prefs,
    WalletSnapshot wallet,
  ) async {
    final syncedHash = _walletStateHashFromSnapshot(wallet);
    await prefs.setString(WalletSyncKeys.lastSyncedStateHash, syncedHash);
    await prefs.setInt(WalletSyncKeys.walletVersion, wallet.version);
    await prefs.setInt(WalletSyncKeys.lastSyncedRemaining, wallet.balanceSeconds);
    await prefs.setInt(
      WalletSyncKeys.lastSyncMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _applyMonitoringFromLocalCache(SharedPreferences prefs) async {
    if (!Platform.isAndroid) return;

    final blockedApps = prefs.getStringList('blocked_apps') ?? <String>[];
    final blockedWebsites = prefs.getStringList('blocked_websites') ?? <String>[];

    try {
      if (blockedApps.isNotEmpty) {
        await _monitoringChannel.invokeMethod('startMonitoring', {
          'blockedApps': blockedApps,
        });
      } else {
        await _monitoringChannel.invokeMethod('updateBlockedApps', {
          'blockedApps': blockedApps,
        });
      }
      await _monitoringChannel.invokeMethod('updateBlockedWebsites', {
        'blockedWebsites': blockedWebsites,
      });
    } catch (_) {}
  }
}
