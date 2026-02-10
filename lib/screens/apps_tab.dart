import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:quit/usage_timer.dart';
import 'package:quit/widgets/hold_to_unblock_button.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:quit/widgets/app_icon_widget.dart';

class AppsSelectionScreen extends StatefulWidget {
  const AppsSelectionScreen({super.key});

  @override
  State<AppsSelectionScreen> createState() => _AppsSelectionScreenState();
}

class _AppsSelectionScreenState extends State<AppsSelectionScreen> {
  List<AppInfo> _installedApps = [];
  Set<String> _blockedApps = {};
  Set<String> _pendingBlockedApps = {};
  bool _loading = true;
  String _searchQuery = '';

  // Timer settings
  UsageTimer? _usageTimer;
  int _dailyLimitMinutes = 0;
  Timer? _timerUpdateTimer;

  // New setting for timer duration
  int _timerDurationIndex = 4; // Default 60 min (0, 5, 15, 30, 60, 120...)

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
    _initializeTimer();

    // Update UI every second to show fresh stats
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
    super.dispose();
  }

  Future<void> _initializeTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _usageTimer = UsageTimer(prefs);
    await _usageTimer!.checkAndResetIfNeeded();

    setState(() {
      // FIX: use dailyLimitSeconds instead of limitSeconds
      _dailyLimitMinutes = (_usageTimer!.dailyLimitSeconds / 60).round();
    });
  }

  Future<void> _loadBlockedApps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final blockedList = prefs.getStringList('blocked_apps') ?? [];
    setState(() {
      _blockedApps = blockedList.toSet();
    });

    // FIX: Use named parameters
    List<AppInfo> apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      withIcon: true,
    );

    // Filter out system apps if needed, or keeping them but sorting
    apps.sort((a, b) => a.name!.toLowerCase().compareTo(b.name!.toLowerCase()));

    if (mounted) {
      setState(() {
        _installedApps = apps;
        _loading = false;
      });
    }

    print(
      '📱 Loaded ${_installedApps.length} apps, ${_blockedApps.length} blocked',
    );
  }

  Future<void> _syncBlockedApps() async {
    const platform = MethodChannel('com.quit.app/monitoring');
    try {
      await platform.invokeMethod('updateBlockedApps', {
        'blockedApps': _blockedApps.toList(),
      });
      print('🔄 Synced blocked apps with native service');
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
      // FIX: use setDailyLimit
      await _usageTimer!.setDailyLimit(minutes * 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = shadcn.Theme.of(context);

    // Filter apps
    final filteredApps = _searchQuery.isEmpty
        ? _installedApps
        : _installedApps
              .where(
                (app) =>
                    app.name!.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    app.packageName!.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    // Sort: Blocked first, then alphabetical
    filteredApps.sort((a, b) {
      final aBlocked = _blockedApps.contains(a.packageName);
      final bBlocked = _blockedApps.contains(b.packageName);
      if (aBlocked && !bBlocked) return -1;
      if (!aBlocked && bBlocked) return 1;
      return a.name!.toLowerCase().compareTo(b.name!.toLowerCase());
    });

    return Column(
      children: [
        // TIMER CONFIG CARD
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: shadcn.Card(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Daily Time Limit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // FIX: Replaced shadcn.Badge with Container styled as badge to avoid import/version issues
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _dailyLimitMinutes == 0
                            ? theme.colorScheme.muted
                            : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _dailyLimitMinutes == 0
                            ? 'Disabled'
                            : '$_dailyLimitMinutes min',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Limit applies to all blocked apps combined.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    _usageTimer?.resetTimer();
                  },
                  child: const Text('Reset Usage'),
                ),
                // Slider using Material
                Slider(
                  value: _dailyLimitMinutes.toDouble(),
                  min: 0,
                  max: 120, // 2 hours max for now
                  divisions: 120, // 1 min increments
                  label: '$_dailyLimitMinutes min',
                  activeColor: const Color(0xFFEF4444),
                  onChanged: (value) {
                    setState(() {
                      _dailyLimitMinutes = value.round();
                    });
                  },
                  onChangeEnd: (value) {
                    _updateDailyLimit(value.round());
                  },
                ),

                if (_dailyLimitMinutes > 0 && _usageTimer != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        // FIX: Removed backgroundColor from shadcn.Card, using Container wrapper instead if needed, but Card usually adapts.
                        // Actually, will just rely on Card default and use Container inside with decoration if needed.
                        // Or use Material Card for specific colors.
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.muted,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.border),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Used Today',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _usageTimer!
                                    .usedTodayFormatted, // FIX: Corrected getter
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.muted,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.border),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Remaining',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _usageTimer!.remainingFormatted,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _usageTimer!.remainingSeconds < 300
                                      ? const Color(0xFFEF4444)
                                      : theme.colorScheme.foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Resets in ${_usageTimer!.formatDuration(_usageTimer!.timeUntilReset())}',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),

        // SEARCH
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search apps...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        const SizedBox(height: 16),

        // APP LIST
        Expanded(
          child: filteredApps.isEmpty
              ? Center(
                  child: Text(
                    'No apps found',
                    style: TextStyle(color: theme.colorScheme.mutedForeground),
                  ),
                )
              : ListView.separated(
                  itemCount: filteredApps.length,
                  padding: const EdgeInsets.only(bottom: 80),
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final app = filteredApps[index];
                    final isBlocked = _blockedApps.contains(app.packageName);

                    return ListTile(
                      // FIX: Pass app object
                      leading: AppIconWidget(app: app),
                      title: Text(
                        app.name ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        app.packageName ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                      trailing: isBlocked
                          ? HoldToUnblockButton(
                              onUnblocked: () async {
                                await _toggleAppBlock(app.packageName!, false);
                              },
                            )
                          : Switch(
                              value: isBlocked,
                              onChanged: (value) {
                                _toggleAppBlock(app.packageName!, value);
                              },
                              activeColor: const Color(0xFFEF4444),
                            ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
