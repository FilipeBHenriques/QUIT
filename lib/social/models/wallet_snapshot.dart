class WalletSnapshot {
  const WalletSnapshot({
    required this.userId,
    required this.balanceSeconds,
    required this.dailyLimitSeconds,
    required this.resetIntervalSeconds,
    this.resetAnchorAt,
    required this.bonusRefillIntervalSeconds,
    required this.bonusAmountSeconds,
    this.lastBonusAt,
    this.dailyTimeRanOutAt,
    required this.updatedAt,
    required this.version,
  });

  final String userId;
  final int balanceSeconds;
  final int dailyLimitSeconds;
  final int resetIntervalSeconds;
  final DateTime? resetAnchorAt;
  final int bonusRefillIntervalSeconds;
  final int bonusAmountSeconds;
  final DateTime? lastBonusAt;
  final DateTime? dailyTimeRanOutAt;
  final DateTime updatedAt;
  final int version;

  factory WalletSnapshot.fromJson(Map<String, dynamic> json) {
    return WalletSnapshot(
      userId: json['user_id'] as String,
      balanceSeconds: json['balance_seconds'] as int? ?? 0,
      dailyLimitSeconds: json['daily_limit_seconds'] as int? ?? 0,
      resetIntervalSeconds: json['reset_interval_seconds'] as int? ?? 86400,
      resetAnchorAt: (json['reset_anchor_at'] as String?) == null
          ? null
          : DateTime.parse(json['reset_anchor_at'] as String),
      bonusRefillIntervalSeconds:
          json['bonus_refill_interval_seconds'] as int? ?? 3600,
      bonusAmountSeconds: json['bonus_amount_seconds'] as int? ?? 300,
      lastBonusAt: (json['last_bonus_at'] as String?) == null
          ? null
          : DateTime.parse(json['last_bonus_at'] as String),
      dailyTimeRanOutAt: (json['daily_time_ran_out_at'] as String?) == null
          ? null
          : DateTime.parse(json['daily_time_ran_out_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int? ?? 0,
    );
  }
}
