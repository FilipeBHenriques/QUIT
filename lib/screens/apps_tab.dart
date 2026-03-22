import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quit/usage_timer.dart';
import 'package:quit/widgets/hold_to_unblock_button.dart';
import 'package:quit/widgets/neon_switch.dart';
import 'package:quit/widgets/neon_slider.dart';
import 'package:quit/widgets/neon_button.dart';
import 'package:quit/widgets/neon_progress_bar.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:quit/screens/app_search_screen.dart';
import 'package:quit/widgets/app_icon_widget.dart';
import 'package:quit/theme/neon_palette.dart';

const Color kAccent = Color(0xFFFF1A5C); // neon rose

class AppsSelectionScreen extends StatefulWidget {
  const AppsSelectionScreen({super.key});

  @override
  State<AppsSelectionScreen> createState() => _AppsSelectionScreenState();
}

class _AppsSelectionScreenState extends State<AppsSelectionScreen> {
  List<AppInfo> _installedApps = [];
  Set<String> _blockedApps = {};
  bool _loading = true;
  bool _blockingMode = true;
  final ScrollController _listController = ScrollController();

  UsageTimer? _usageTimer;
  int _dailyLimitMinutes = 0;
  Timer? _timerUpdateTimer;
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
    _initializeTimer();

    _timerUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isSearchOpen && _usageTimer != null) {
        _usageTimer!.reload().then((_) => setState(() {}));
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
    _usageTimer = UsageTimer(prefs);
    await _usageTimer!.checkAndResetIfNeeded();
    setState(() {
      _dailyLimitMinutes = (_usageTimer!.dailyLimitSeconds / 60).round();
    });
  }

  Future<void> _loadBlockedApps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final blockedList = prefs.getStringList('blocked_apps') ?? [];
    setState(() => _blockedApps = blockedList.toSet());

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
    await _syncBlockedApps();
  }

  Future<void> _updateDailyLimit(int minutes) async {
    setState(() => _dailyLimitMinutes = minutes);
    if (_usageTimer != null) {
      await _usageTimer!.setDailyLimit(minutes * 60);
    }
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
          // ── Blocking Mode ──
          _SettingsCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blocking Mode',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: NeonPalette.text,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Block immediately when selected',
                        style: TextStyle(
                          fontSize: 11,
                          color: NeonPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                NeonSwitch(
                  value: _blockingMode,
                  onChanged: (value) => setState(() => _blockingMode = value),
                  activeColor: kAccent,
                ),
              ],
            ),
          ),

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
                  max: 120,
                  divisions: 120,
                  onChanged: (v) =>
                      setState(() => _dailyLimitMinutes = v.round()),
                  onChangeEnd: (v) => _updateDailyLimit(v.round()),
                  activeColor: kAccent,
                ),
                if (_dailyLimitMinutes > 0 && _usageTimer != null) ...[
                  const SizedBox(height: 18),
                  NeonProgressBar(
                    value: _usageTimer!.usedTodaySeconds.toDouble(),
                    max: _usageTimer!.dailyLimitSeconds.toDouble(),
                    color: kAccent,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatColumn(
                          label: 'Used Today',
                          value: _usageTimer!.usedTodayFormatted,
                          valueColor: kAccent,
                          align: CrossAxisAlignment.start,
                        ),
                      ),
                      Expanded(
                        child: _StatColumn(
                          label: 'Remaining',
                          value: _usageTimer!.remainingFormatted,
                          valueColor: NeonPalette.text,
                          align: CrossAxisAlignment.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Resets in ${_usageTimer!.formatDuration(_usageTimer!.timeUntilReset())}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: NeonPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  NeonButton(
                    onPressed: () {
                      _usageTimer?.resetTimer();
                      setState(() {});
                    },
                    text: 'Reset Usage',
                    color: kAccent.withValues(alpha: 0.08),
                    textColor: kAccent,
                    borderColor: kAccent.withValues(alpha: 0.30),
                    glowColor: kAccent,
                    glowOpacity: 0.10,
                    borderRadius: 10,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    fontSize: 13,
                  ),
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
                  border: Border.all(
                    color: NeonPalette.border,
                    width: 0.5,
                  ),
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
                      final isBlocked =
                          _blockedApps.contains(app.packageName);

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
