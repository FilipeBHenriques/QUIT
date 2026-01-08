import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Set<String> _togglingApps =
      {}; // Track which apps are currently being toggled
  bool _loadingPrefs = true;
  late Future<List<AppInfo>> _appsFuture; // Cache the future

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
    _appsFuture = InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );
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
    // Optimistically update UI
    setState(() {
      if (blocked) {
        _blockedApps.add(packageName);
      } else {
        _blockedApps.remove(packageName);
      }
      _togglingApps.add(packageName);
    });

    // Save in background
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('blocked_apps', _blockedApps.toList());

      // Update the monitoring service
      await platform.invokeMethod('updateBlockedApps', {
        'blockedApps': _blockedApps.toList(),
      });
      print('✅ Updated monitoring service with ${_blockedApps.length} apps');
    } catch (e) {
      print('❌ Error updating: $e');
      // Revert on error
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
      body: _loadingPrefs
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<AppInfo>>(
              future: _appsFuture, // Use cached future
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
                // Filter out this app and sort alphabetically
                final userApps =
                    apps
                        .where((app) => app.packageName != 'com.example.quit')
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
                    final isBlocked = _blockedApps.contains(app.packageName);
                    final isToggling = _togglingApps.contains(app.packageName);

                    return ListTile(
                      leading: AppIconWidget(app: app),
                      title: Text(
                        app.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        app.packageName,
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
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
                                await _toggleAppBlocked(app.packageName, false);
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
