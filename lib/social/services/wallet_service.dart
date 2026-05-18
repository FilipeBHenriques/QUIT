import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallet_snapshot.dart';

class WalletService {
  WalletService(this._client);

  final SupabaseClient _client;

  Future<WalletSnapshot> getWallet() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('No authenticated user');
    }
    final row = await _client
        .from('time_wallets')
        .select()
        .eq('user_id', uid)
        .single();
    return WalletSnapshot.fromJson(row);
  }

  Future<Map<String, dynamic>> getTransferLimits() async {
    final result = await _client.rpc('get_transfer_limits');
    return (result as Map).cast<String, dynamic>();
  }

  Future<WalletSnapshot> setWalletState({
    required int balanceSeconds,
    required int dailyLimitSeconds,
    required int resetIntervalSeconds,
    required int resetAnchorMs,
    required int bonusRefillIntervalSeconds,
    required int bonusAmountSeconds,
    required int lastBonusMs,
    required int dailyTimeRanOutMs,
  }) async {
    final result = await _client.rpc('set_wallet_state', params: {
      'p_balance_seconds': balanceSeconds,
      'p_daily_limit_seconds': dailyLimitSeconds,
      'p_reset_interval_seconds': resetIntervalSeconds,
      'p_reset_anchor_ms': resetAnchorMs,
      'p_bonus_refill_interval_seconds': bonusRefillIntervalSeconds,
      'p_bonus_amount_seconds': bonusAmountSeconds,
      'p_last_bonus_ms': lastBonusMs,
      'p_daily_time_ran_out_ms': dailyTimeRanOutMs,
    });
    return WalletSnapshot.fromJson((result as Map).cast<String, dynamic>());
  }

  Future<void> sendTimeGift({required String toUserId, required int seconds, String? memo}) async {
    await _client.rpc('send_time_gift', params: {
      'p_to_user_id': toUserId,
      'p_seconds': seconds,
      'p_memo': memo,
    });
  }
}
