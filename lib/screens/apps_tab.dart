import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quit/usage_timer.dart';
import 'package:quit/widgets/hold_to_unblock_button.dart';
import 'package:quit/widgets/neon_switch.dart';
import 'package:quit/widgets/neon_slider.dart';
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

  Future<bool> _isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('guest_mode') ?? false;
  }

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
  }

  Future<void> _loadBlockedApps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final localBlocked = (prefs.getStringList('blocked_apps') ?? []).toSet();
    setState(() => _blockedApps = localBlocked);
    final appsFuture = InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    );
    try {
      if (await _isGuestMode()) {
        throw Exception('guest_local_mode');
      }
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final row = await Supabase.instance.client
            .from('user_blocklists')
            .select('blocked_apps')
            .eq('user_id', uid)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        if (row != null) {
          final remoteBlocked =
              ((row['blocked_apps'] as List?) ?? const <dynamic>[])
                  .map((e) => e.toString())
                  .toSet();
          await prefs.setStringList('blocked_apps', remoteBlocked.toList());
          if (mounted) {
            setState(() => _blockedApps = remoteBlocked);
          }
        }
      }
    } catch (_) {}
    List<AppInfo> apps = await appsFuture;
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
    if (await _isGuestMode()) return;
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
      }).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<void> _syncBlocklistsToDb(SharedPreferences prefs) async {
    if (await _isGuestMode()) return;
    try {
      await Supabase.instance.client.rpc('set_user_blocklists', params: {
        'p_blocked_apps': prefs.getStringList('blocked_apps') ?? <String>[],
        'p_blocked_websites': prefs.getStringList('blocked_websites') ?? <String>[],
        'p_custom_websites': prefs.getStringList('custom_website_urls') ?? <String>[],
      }).timeout(const Duration(seconds: 4));
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: NeonPalette.surfaceSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: NeonPalette.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: NeonPalette.mint,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Time you can use now',
                          style: TextStyle(
                            fontSize: 11,
                            color: NeonPalette.textMuted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _usageTimer!.formatSeconds(
                            _usageTimer!.walletRemainingSeconds,
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: NeonPalette.mint,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 6),
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
                  Text(
                    'Daily reset (24h): ${_usageTimer!.formatDuration(_usageTimer!.timeUntilReset())}',
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
