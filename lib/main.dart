import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quit/usage_timer.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'screens/blocked_screen.dart';

const int holdDurationSeconds = 5;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const QuitApp());
}

class QuitApp extends StatelessWidget {
  const QuitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QUIT App',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
      routes: {'/blocked': (context) => const BlockedScreen()},
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.quit.app/monitoring');
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMonitoringIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startMonitoringIfNeeded();
    }
  }

  Future<void> _startMonitoringIfNeeded() async {
    if (!Platform.isAndroid) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];

    if (blockedApps.isNotEmpty && !_isMonitoring) {
      try {
        await platform.invokeMethod('startMonitoring', {
          'blockedApps': blockedApps,
        });
        setState(() {
          _isMonitoring = true;
        });
        print('✅ Monitoring started with ${blockedApps.length} apps');
      } catch (e) {
        print('❌ Error starting monitoring: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AppsSelectionScreen(),
              ),
            );
            // Restart monitoring with updated list when returning
            setState(() {
              _isMonitoring = false;
            });
            _startMonitoringIfNeeded();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 150,
            height: 150,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.block, size: 80, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

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

  // Timer & Usage Limit
  late UsageTimer _usageTimer;
  int _dailyLimitMinutes = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initializeTimer();
    _loadBlockedApps();
    _appsFuture = InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );

    // Poll SharedPreferences every second for real-time updates
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _usageTimer.reload();

      // Check if reset just occurred
      if (_usageTimer.shouldReset()) {
        await _usageTimer.resetTimer();
        print('🔄 Reset detected - refreshing UI');
      }

      if (mounted) {
        setState(() {
          // Triggers rebuild with latest data from SharedPreferences
          // This includes: used time, remaining time, reset countdown
        });
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
    await _usageTimer.checkAndResetIfNeeded();
    if (mounted) {
      setState(() {
        _dailyLimitMinutes = (_usageTimer.dailyLimitSeconds / 60).round();
      });
    }
  }

  Future<void> _updateDailyLimit(int minutes) async {
    print('🔄 Updating daily limit to: $minutes minutes');

    // Update limit (preserves used time)
    await _usageTimer.setDailyLimit(minutes * 60);

    if (mounted) {
      setState(() {
        _dailyLimitMinutes = minutes;
      });
    }

    // Notify monitoring service
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Select Apps to Block'),
        backgroundColor: Colors.grey[900],
      ),
      body: Column(
        children: [
          // TIMER CONFIGURATION SECTION
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // DAILY LIMIT HEADER
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
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // SLIDER
                Slider(
                  value: _dailyLimitMinutes.toDouble(),
                  min: 0,
                  max: 60,
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

                // TIMER STATS (shown when limit > 0)
                if (_dailyLimitMinutes > 0) ...[
                  const SizedBox(height: 12),

                  // Row 1: Used Today | Remaining
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Used Today
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
                            _usageTimer.usedTodayFormatted,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),

                      // Remaining
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
                            _usageTimer.remainingFormatted,
                            style: TextStyle(
                              fontSize: 18,
                              color: _usageTimer.remainingSeconds > 0
                                  ? Colors.greenAccent
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Resets In
                  Text(
                    'Resets in: ${_usageTimer.formatTimeUntilReset()}',
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
                        return const Center(
                          child: Text(
                            'No apps found',
                            style: TextStyle(color: Colors.white),
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
      ),
    );
  }
}

// Widget to properly display app icons
class AppIconWidget extends StatelessWidget {
  final AppInfo app;

  const AppIconWidget({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    if (app.icon != null && app.icon!.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            app.icon!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultIcon();
            },
          ),
        ),
      );
    }
    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.android, color: Colors.white, size: 32),
    );
  }
}

class HoldToUnblockButton extends StatefulWidget {
  final Future<void> Function() onUnblocked;

  const HoldToUnblockButton({super.key, required this.onUnblocked});

  @override
  State<HoldToUnblockButton> createState() => _HoldToUnblockButtonState();
}

class _HoldToUnblockButtonState extends State<HoldToUnblockButton> {
  bool _holding = false;
  Timer? _timer;
  int _secondsHeld = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _holding = true;
          _secondsHeld = 0;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _secondsHeld++;
          });
          if (_secondsHeld >= holdDurationSeconds) {
            timer.cancel();
            widget.onUnblocked().then((_) {
              if (mounted) {
                setState(() {
                  _holding = false;
                  _secondsHeld = 0;
                });
              }
            });
          }
        });
      },
      onTapUp: (_) {
        _timer?.cancel();
        setState(() {
          _holding = false;
          _secondsHeld = 0;
        });
      },
      onTapCancel: () {
        _timer?.cancel();
        setState(() {
          _holding = false;
          _secondsHeld = 0;
        });
      },
      child: Container(
        width: 80,
        height: 40,
        decoration: BoxDecoration(
          color: _holding ? Colors.redAccent : Colors.grey[700],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            _holding ? '${holdDurationSeconds - _secondsHeld}s' : 'Hold',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
