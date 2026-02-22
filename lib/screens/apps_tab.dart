import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quit/usage_timer.dart';
import 'package:quit/widgets/hold_to_unblock_button.dart';
import 'package:quit/widgets/neon_card.dart';
import 'package:quit/widgets/neon_switch.dart';
import 'package:quit/widgets/neon_slider.dart';
import 'package:quit/widgets/neon_button.dart';
import 'package:quit/widgets/neon_progress_bar.dart';
import 'package:quit/widgets/neon_text_field.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:quit/widgets/app_icon_widget.dart';
import 'package:quit/theme/neon_palette.dart';

const Color kRed = Color(0xFFEF4444);
const Color kWhite = NeonPalette.text;

class AppsSelectionScreen extends StatefulWidget {
  const AppsSelectionScreen({super.key});

  @override
  State<AppsSelectionScreen> createState() => _AppsSelectionScreenState();
}

class _AppsSelectionScreenState extends State<AppsSelectionScreen> {
  List<AppInfo> _installedApps = [];
  Set<String> _blockedApps = {};
  bool _loading = true;
  String _searchQuery = '';
  bool _blockingMode = true;
  final ScrollController _listController = ScrollController();

  UsageTimer? _usageTimer;
  int _dailyLimitMinutes = 0;
  Timer? _timerUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
    _initializeTimer();

    _timerUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _usageTimer != null) {
        _usageTimer!.reload().then((_) {
          setState(() {});
        });
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
    setState(() {
      _blockedApps = blockedList.toSet();
    });

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
    } catch (e) {
      print('❌ Error syncing blocked apps: $e');
    }
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
    setState(() {
      _dailyLimitMinutes = minutes;
    });

    if (_usageTimer != null) {
      await _usageTimer!.setDailyLimit(minutes * 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    final filteredApps = _searchQuery.isEmpty
        ? _installedApps
        : _installedApps
              .where(
                (app) =>
                    app.name.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    app.packageName.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    filteredApps.sort((a, b) {
      final aBlocked = _blockedApps.contains(a.packageName);
      final bBlocked = _blockedApps.contains(b.packageName);
      if (aBlocked && !bBlocked) return -1;
      if (!aBlocked && bBlocked) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(gradient: NeonPalette.pageGlow),
        child: Column(
          children: [
            // Blocking Mode Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: NeonCard(
                glowColor: kRed, // All neon color is red now
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
                              color: kWhite,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                      onChanged: (value) {
                        setState(() {
                          _blockingMode = value;
                        });
                      },
                      activeColor: kRed,
                    ),
                  ],
                ),
              ),
            ),

            // Daily Time Limit Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: NeonCard(
                glowColor: kRed, // All neon color is red now
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
                            color: kWhite,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          '$_dailyLimitMinutes min/day',
                          style: const TextStyle(fontSize: 12, color: kRed),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    NeonSlider(
                      value: _dailyLimitMinutes.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 120,
                      onChanged: (value) {
                        setState(() {
                          _dailyLimitMinutes = value.round();
                        });
                      },
                      onChangeEnd: (value) {
                        _updateDailyLimit(value.round());
                      },
                      activeColor: kRed,
                    ),
                    if (_dailyLimitMinutes > 0 && _usageTimer != null) ...[
                      const SizedBox(height: 16),
                      NeonProgressBar(
                        value: _usageTimer!.usedTodaySeconds.toDouble(),
                        max: _usageTimer!.dailyLimitSeconds.toDouble(),
                        color: kRed,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Used Today',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: NeonPalette.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _usageTimer!.usedTodayFormatted,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: kRed,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Remaining',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: NeonPalette.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _usageTimer!.remainingFormatted,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: kWhite,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Resets in: ${_usageTimer!.formatDuration(_usageTimer!.timeUntilReset())}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: NeonPalette.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      NeonButton(
                        onPressed: () {
                          _usageTimer?.resetTimer();
                          setState(() {});
                        },
                        text: 'Reset Usage',
                        color: kRed,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: NeonTextField(
                placeholder: 'Search apps...',
                leading: const Icon(Icons.search, color: NeonPalette.textMuted),
                onChanged: (value) {
                  if (_listController.hasClients) {
                    _listController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                    );
                  }
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // App List
            Expanded(
              child: filteredApps.isEmpty
                  ? const Center(
                      child: Text(
                        'No apps found',
                        style: TextStyle(color: kWhite),
                      ),
                    )
                  : ListView.separated(
                      controller: _listController,
                      itemCount: filteredApps.length,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        80 + keyboardInset,
                      ),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final app = filteredApps[index];
                        final isBlocked = _blockedApps.contains(
                          app.packageName,
                        );

                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: NeonPalette.border),
                            borderRadius: BorderRadius.circular(12),
                            color: NeonPalette.surface,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: NeonPalette.surfaceSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(child: AppIconWidget(app: app)),
                            ),
                            title: Text(
                              app.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: kWhite,
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
                                    onUnblocked: () async {
                                      await _toggleAppBlock(
                                        app.packageName,
                                        false,
                                      );
                                    },
                                  )
                                : NeonSwitch(
                                    value: isBlocked,
                                    onChanged: (value) {
                                      _toggleAppBlock(app.packageName, value);
                                    },
                                    activeColor: kRed,
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
