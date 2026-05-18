import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quit/usage_timer.dart';
import 'package:quit/widgets/hold_to_unblock_button.dart';
import 'package:quit/widgets/neon_switch.dart';
import 'package:quit/widgets/neon_slider.dart';
import 'package:quit/widgets/neon_progress_bar.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:quit/screens/app_search_screen.dart';
import 'package:quit/widgets/app_icon_widget.dart';
import 'package:quit/theme/neon_palette.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color kAccent = Color(0xFFFF1A5C); // neon rose

class AppsSelectionScreen extends StatefulWidget {
  const AppsSelectionScreen({super.key});

  @override
  State<AppsSelectionScreen> createState() => _AppsSelectionScreenState();
}

class _AppsSelectionScreenState extends State<AppsSelectionScreen> {
  static const int _sliderStepMinutes = 30;
  static const int _sliderSoftCapMinutes = 120;

  List<AppInfo> _installedApps = [];
  Set<String> _blockedApps = {};
  bool _loading = true;
  final ScrollController _listController = ScrollController();

  UsageTimer? _usageTimer;
  int _dailyLimitMinutes = 0;
  int _dailyLimitSliderMaxMinutes = _sliderSoftCapMinutes;
  Timer? _timerUpdateTimer;
  bool _isSearchOpen = false;
  int _todaySentSeconds = 0;
  int _todayReceivedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
    _initializeTimer();

    _timerUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (mounted && !_isSearchOpen && _usageTimer != null) {
        await _usageTimer!.reload();
        setState(() {});
      }
    });
    _loadTodayTransferStats();
  }

  @override
  void dispose() {
    _timerUpdateTimer?.cancel();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _initializeTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // get fresh data immediately on open
    _usageTimer = UsageTimer(prefs);
    await _usageTimer!.checkAndResetIfNeeded();
    setState(() {
      _dailyLimitMinutes = (_usageTimer!.dailyLimitSeconds / 60).round();
      _dailyLimitSliderMaxMinutes = _sliderMaxForMinutes(_dailyLimitMinutes);
    });
    await _loadTodayTransferStats();
  }

  Future<void> _loadTodayTransferStats() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();

      final sentRows = await Supabase.instance.client
          .from('time_transfers')
          .select('seconds,type')
          .eq('sender_id', uid)
          .eq('status', 'completed')
          .inFilter('type', ['gift', 'request_approved'])
          .gte('created_at', start);

      final receivedRows = await Supabase.instance.client
          .from('time_transfers')
          .select('seconds,type')
          .eq('receiver_id', uid)
          .eq('status', 'completed')
          .inFilter('type', ['gift', 'request_approved'])
          .gte('created_at', start);

      int sent = 0;
      int received = 0;
      for (final row in (sentRows as List)) {
        sent += ((row as Map<String, dynamic>)['seconds'] as int?) ?? 0;
      }
      for (final row in (receivedRows as List)) {
        received += ((row as Map<String, dynamic>)['seconds'] as int?) ?? 0;
      }
      if (!mounted) return;
      setState(() {
        _todaySentSeconds = sent;
        _todayReceivedSeconds = received;
      });
    } catch (_) {}
  }

  Future<void> _loadBlockedApps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final blockedList = prefs.getStringList('blocked_apps') ?? [];
    var effectiveBlocked = blockedList.toSet();
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final row = await Supabase.instance.client
            .from('user_blocklists')
            .select('blocked_apps')
            .eq('user_id', uid)
            .maybeSingle();
        if (row != null) {
          final remoteBlocked =
              ((row['blocked_apps'] as List?) ?? const <dynamic>[])
                  .map((e) => e.toString())
                  .toSet();
          effectiveBlocked = remoteBlocked;
          await prefs.setStringList('blocked_apps', remoteBlocked.toList());
        }
      }
    } catch (_) {}
    setState(() => _blockedApps = effectiveBlocked);

    List<AppInfo> apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    );
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (mounted) {
      setState(() {
        _installedApps = apps;
        _loading = false;
      });
    }
  }

  Future<void> _syncBlockedApps() async {
    const platform = MethodChannel('com.quit.app/monitoring');
    try {
      await platform.invokeMethod('updateBlockedApps', {
        'blockedApps': _blockedApps.toList(),
      });
    } catch (_) {}
  }

  Future<void> _toggleAppBlock(String packageName, bool blocked) async {
    setState(() {
      if (blocked) {
        _blockedApps.add(packageName);
      } else {
        _blockedApps.remove(packageName);
      }
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_apps', _blockedApps.toList());
    await _syncBlocklistsToDb(prefs);
    await _syncBlockedApps();
  }

  Future<void> _updateDailyLimit(int minutes) async {
    setState(() {
      _dailyLimitMinutes = minutes;
      // Shrink the slider range back to what's appropriate for this value.
      // Expansion still works (dragging to the edge grows the max), but
      // settling on a lower number locks the ceiling back down.
      _dailyLimitSliderMaxMinutes = _sliderMaxForMinutes(minutes);
    });
    if (_usageTimer != null) {
      await _usageTimer!.setDailyLimit(minutes * 60);
      final prefs = await SharedPreferences.getInstance();
      await _syncTimerConfigToNative(minutes * 60);
      await _syncWalletStateToDb(prefs);
      await _usageTimer!.reload();
      if (mounted) setState(() {});
    }
  }

  Future<void> _syncTimerConfigToNative(int dailyLimitSeconds) async {
    const platform = MethodChannel('com.quit.app/monitoring');
    try {
      await platform.invokeMethod('updateTimerConfig', {
        'dailyLimitSeconds': dailyLimitSeconds,
      });
    } catch (_) {}
  }

  Future<void> _syncWalletStateToDb(SharedPreferences prefs) async {
    try {
      await Supabase.instance.client.rpc('set_wallet_state', params: {
        'p_balance_seconds': prefs.getInt('remaining_seconds') ?? 0,
        'p_daily_limit_seconds': prefs.getInt('daily_limit_seconds') ?? 0,
        'p_reset_interval_seconds': prefs.getInt('reset_interval_seconds') ?? 86400,
        'p_reset_anchor_ms': prefs.getInt('timer_last_reset') ?? 0,
        'p_bonus_refill_interval_seconds': prefs.getInt('bonus_refill_interval_seconds') ?? 3600,
        'p_bonus_amount_seconds': prefs.getInt('bonus_amount_seconds') ?? 300,
        'p_last_bonus_ms': prefs.getInt('last_bonus_time') ?? 0,
        'p_daily_time_ran_out_ms': prefs.getInt('daily_time_ran_out_timestamp') ?? 0,
      });
    } catch (_) {}
  }

  Future<void> _syncBlocklistsToDb(SharedPreferences prefs) async {
    try {
      await Supabase.instance.client.rpc('set_user_blocklists', params: {
        'p_blocked_apps': prefs.getStringList('blocked_apps') ?? <String>[],
        'p_blocked_websites': prefs.getStringList('blocked_websites') ?? <String>[],
        'p_custom_websites': prefs.getStringList('custom_website_urls') ?? <String>[],
      });
    } catch (_) {}
  }

  int _sliderMaxForMinutes(int minutes) {
    if (minutes <= _sliderSoftCapMinutes) return _sliderSoftCapMinutes;
    final extra = minutes - _sliderSoftCapMinutes;
    final steps = (extra / _sliderStepMinutes).ceil();
    return _sliderSoftCapMinutes + ((steps + 1) * _sliderStepMinutes);
  }

  void _handleDailyLimitDrag(double value) {
    final rounded = value.round();
    final shouldExpand = rounded >= _dailyLimitSliderMaxMinutes - 2;
    setState(() {
      _dailyLimitMinutes = rounded;
      if (shouldExpand) {
        _dailyLimitSliderMaxMinutes += _sliderStepMinutes;
      }
    });
  }

  Future<void> _openSearchMode() async {
    _isSearchOpen = true;
    final updatedBlockedApps = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (context) => AppSearchScreen(
          installedApps: _installedApps,
          blockedApps: _blockedApps,
          onToggleAppBlock: _toggleAppBlock,
        ),
      ),
    );
    _isSearchOpen = false;
    if (!mounted) return;
    if (updatedBlockedApps != null) {
      setState(() => _blockedApps = updatedBlockedApps);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: kAccent, strokeWidth: 1.5),
      );
    }

    final transferAdjustedUsedSeconds =
        ((_usageTimer?.usedTodaySeconds ?? 0) + _todaySentSeconds)
            .clamp(0, 1 << 31);
    final transferAdjustedDailyRemainingSeconds = (_usageTimer == null)
        ? 0
        : (_usageTimer!.dailyLimitSeconds - transferAdjustedUsedSeconds)
            .clamp(0, 1 << 31);
    final transferAdjustedGoalUsedSeconds = (_usageTimer == null)
        ? 0
        : transferAdjustedUsedSeconds.clamp(0, _usageTimer!.dailyLimitSeconds);

    final displayedApps = List<AppInfo>.from(_installedApps)
      ..sort((a, b) {
        final aBlocked = _blockedApps.contains(a.packageName);
        final bBlocked = _blockedApps.contains(b.packageName);
        if (aBlocked && !bBlocked) return -1;
        if (!aBlocked && bBlocked) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Container(
      color: NeonPalette.bg,
      child: Column(
        children: [
          const SizedBox(height: 2),
          // ── Daily Time Limit ──
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily Time Limit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: NeonPalette.text,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      '$_dailyLimitMinutes min / day',
                      style: const TextStyle(
                        fontSize: 12,
                        color: kAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                NeonSlider(
                  value: _dailyLimitMinutes.toDouble(),
                  min: 0,
                  max: _dailyLimitSliderMaxMinutes.toDouble(),
                  divisions: _dailyLimitSliderMaxMinutes,
                  onChanged: _handleDailyLimitDrag,
                  onChangeEnd: (v) => _updateDailyLimit(v.round()),
                  activeColor: kAccent,
                ),
                const SizedBox(height: 8),
                Text(
                  _dailyLimitSliderMaxMinutes <= _sliderSoftCapMinutes
                      ? 'Drag to set your goal. It expands if you need more.'
                      : 'Keep dragging near the edge to extend the limit.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: NeonPalette.textMuted,
                  ),
                ),
                if (_usageTimer != null) ...[
                  const SizedBox(height: 18),
                  if (_dailyLimitMinutes > 0)
                    NeonProgressBar(
                      value: transferAdjustedGoalUsedSeconds.toDouble(),
                      max: _usageTimer!.dailyLimitSeconds.toDouble(),
                      color: kAccent,
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatColumn(
                          label: 'Goal Used',
                          value: _dailyLimitMinutes > 0
                              ? _usageTimer!.formatSeconds(
                                  transferAdjustedGoalUsedSeconds,
                                )
                              : '0:00',
                          valueColor: kAccent,
                          align: CrossAxisAlignment.start,
                        ),
                      ),
                      Expanded(
                        child: _StatColumn(
                          label: 'Before Limit',
                          value: _usageTimer!.formatSeconds(
                            transferAdjustedDailyRemainingSeconds,
                          ),
                          valueColor: NeonPalette.text,
                          align: CrossAxisAlignment.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatColumn(
                          label: 'Available',
                          value: _usageTimer!.formatSeconds(_usageTimer!.walletRemainingSeconds),
                          valueColor: NeonPalette.mint,
                          align: CrossAxisAlignment.start,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatColumn(
                          label: 'Sent Today',
                          value: _usageTimer!.formatSeconds(_todaySentSeconds),
                          valueColor: NeonPalette.textMuted,
                          align: CrossAxisAlignment.start,
                        ),
                      ),
                      Expanded(
                        child: _StatColumn(
                          label: 'Received Today',
                          value: _usageTimer!.formatSeconds(_todayReceivedSeconds),
                          valueColor: NeonPalette.textMuted,
                          align: CrossAxisAlignment.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Daily goal reflects screen use + sent transfers. Received transfers still raise available balance.',
                    style: TextStyle(fontSize: 10, color: NeonPalette.textMuted),
                  ),
                  if (_usageTimer!.bonusUsedTodaySeconds > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(
                            0xFFFFB800,
                          ).withValues(alpha: 0.25),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 13,
                            color: Color(0xFFFFB800),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Bonus used',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFFFB800),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _usageTimer!.bonusUsedTodayFormatted,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFB800),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (_dailyLimitMinutes > 0)
                    Text(
                      'Resets in ${_usageTimer!.formatDuration(_usageTimer!.timeUntilReset())}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: NeonPalette.textMuted,
                      ),
                    ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),

          const SizedBox(height: 2),

          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GestureDetector(
              onTap: _openSearchMode,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: NeonPalette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NeonPalette.border, width: 0.5),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: NeonPalette.textMuted,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Search apps...',
                      style: TextStyle(
                        color: NeonPalette.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── App list ──
          Expanded(
            child: displayedApps.isEmpty
                ? const Center(
                    child: Text(
                      'No apps found',
                      style: TextStyle(color: NeonPalette.textMuted),
                    ),
                  )
                : ListView.separated(
                    controller: _listController,
                    itemCount: displayedApps.length,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final app = displayedApps[index];
                      final isBlocked = _blockedApps.contains(app.packageName);

                      return Container(
                        decoration: BoxDecoration(
                          color: isBlocked
                              ? kAccent.withValues(alpha: 0.04)
                              : NeonPalette.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isBlocked
                                ? kAccent.withValues(alpha: 0.22)
                                : NeonPalette.border,
                            width: 0.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: NeonPalette.surfaceSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(child: AppIconWidget(app: app)),
                          ),
                          title: Text(
                            app.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: NeonPalette.text,
                            ),
                          ),
                          subtitle: Text(
                            app.packageName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: NeonPalette.textMuted,
                            ),
                          ),
                          trailing: isBlocked
                              ? HoldToUnblockButton(
                                  onUnblocked: () async =>
                                      _toggleAppBlock(app.packageName, false),
                                )
                              : NeonSwitch(
                                  value: isBlocked,
                                  onChanged: (v) =>
                                      _toggleAppBlock(app.packageName, v),
                                  activeColor: kAccent,
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NeonPalette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NeonPalette.border, width: 0.5),
        ),
        child: child,
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final CrossAxisAlignment align;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.align,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: NeonPalette.textMuted),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: valueColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
