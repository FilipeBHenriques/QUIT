import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const platform = MethodChannel('com.quit.app/monitoring');

  Set<String> _blockedApps = {};
  Set<String> _togglingApps = {};
  bool _loadingPrefs = true;
  late Future<List<AppInfo>> _appsFuture;

  UsageTimer? _usageTimer;
  int _dailyLimitMinutes = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
    _loadBlockedApps();
    _appsFuture = InstalledApps.getInstalledApps(
      excludeSystemApps: false,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );

    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_usageTimer != null) {
        await _usageTimer!.reload();

        if (_usageTimer!.shouldReset()) {
          await _usageTimer!.resetTimer();
          print('🔄 Reset detected - refreshing UI');
        }

        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTimer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _usageTimer = UsageTimer(prefs);
    await _usageTimer!.checkAndResetIfNeeded();
    if (mounted) {
      setState(() {
        _dailyLimitMinutes = (_usageTimer!.dailyLimitSeconds / 60).round();
      });
    }
  }

  Future<void> _updateDailyLimit(int minutes) async {
    if (_usageTimer == null) return;

    print('🔄 Updating daily limit to: $minutes minutes');

    await _usageTimer!.setDailyLimit(minutes * 60);

    if (mounted) {
      setState(() {
        _dailyLimitMinutes = minutes;
      });
    }

    try {
      await platform.invokeMethod('updateTimerConfig', {
        'dailyLimitSeconds': minutes * 60,
      });
      print('✅ Timer config updated in service');
    } catch (e) {
      print('❌ Error updating timer config: $e');
    }
  }

  Future<void> _loadBlockedApps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final list = prefs.getStringList('blocked_apps') ?? [];
    if (mounted) {
      setState(() {
        _blockedApps = list.toSet();
        _loadingPrefs = false;
      });
    }
  }

  Future<void> _toggleAppBlocked(String packageName, bool blocked) async {
    setState(() {
      if (blocked) {
        _blockedApps.add(packageName);
      } else {
        _blockedApps.remove(packageName);
      }
      _togglingApps.add(packageName);
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_apps', _blockedApps.toList());

      await platform.invokeMethod('updateBlockedApps', {
        'blockedApps': _blockedApps.toList(),
      });
      print('✅ Updated monitoring service with ${_blockedApps.length} apps');
    } catch (e) {
      print('❌ Error updating: $e');
      setState(() {
        if (blocked) {
          _blockedApps.remove(packageName);
        } else {
          _blockedApps.add(packageName);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _togglingApps.remove(packageName);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TIMER CONFIGURATION SECTION
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[900],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Daily Time Limit',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _dailyLimitMinutes == 0
                        ? 'Disabled'
                        : '${_dailyLimitMinutes} min/day',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Slider(
                value: _dailyLimitMinutes.toDouble(),
                min: 0,
                max: 120,
                divisions: null,
                label: _dailyLimitMinutes == 0
                    ? 'Disabled'
                    : '$_dailyLimitMinutes min',
                onChanged: (value) {
                  setState(() {
                    _dailyLimitMinutes = value.round();
                  });
                },
                onChangeEnd: (value) {
                  _updateDailyLimit(value.round());
                },
                activeColor: Colors.redAccent,
              ),

              if (_dailyLimitMinutes > 0 && _usageTimer != null) ...[
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Used Today',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _usageTimer!.usedTodayFormatted,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Remaining',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _usageTimer!.remainingFormatted,
                          style: TextStyle(
                            fontSize: 18,
                            color: _usageTimer!.remainingSeconds > 0
                                ? Colors.greenAccent
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  'Resets in: ${_usageTimer!.formatTimeUntilReset()}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white24),

        // APP LIST
        Expanded(
          child: _loadingPrefs
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<AppInfo>>(
                  future: _appsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading apps: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'No apps found',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Make sure you have granted permissions',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final apps = snapshot.data!;
                    final userApps =
                        apps
                            .where(
                              (app) => app.packageName != 'com.example.quit',
                            )
                            .toList()
                          ..sort(
                            (a, b) => a.name.toLowerCase().compareTo(
                              b.name.toLowerCase(),
                            ),
                          );

                    return ListView.builder(
                      itemCount: userApps.length,
                      itemBuilder: (context, index) {
                        final app = userApps[index];
                        final isBlocked = _blockedApps.contains(
                          app.packageName,
                        );
                        final isToggling = _togglingApps.contains(
                          app.packageName,
                        );

                        return ListTile(
                          leading: AppIconWidget(app: app),
                          title: Text(
                            app.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            app.packageName,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isToggling
                              ? const SizedBox(
                                  width: 80,
                                  height: 40,
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : isBlocked
                              ? HoldToUnblockButton(
                                  onUnblocked: () async {
                                    await _toggleAppBlocked(
                                      app.packageName,
                                      false,
                                    );
                                  },
                                )
                              : Switch(
                                  value: isBlocked,
                                  onChanged: (value) {
                                    _toggleAppBlocked(app.packageName, value);
                                  },
                                  activeColor: Colors.redAccent,
                                  inactiveThumbColor: Colors.white,
                                ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
