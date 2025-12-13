// lib/main.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'services/app_sevice.dart';
import 'services/app_blocking_service.dart';
import 'screens/blocked_screen.dart';
import 'package:installed_apps/app_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global navigator key to navigate from anywhere (including background services)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Helper function to get the home widget (used when navigating back from blocking screen)
Widget getHomeWidget() => const AppBlockingWrapper();

void main() {
  runApp(const QuitApp());
}

class QuitApp extends StatelessWidget {
  const QuitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'QUIT App',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.dark,
          primary: Colors.white,
          secondary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        useMaterial3: true,
      ),
      home: const AppBlockingWrapper(),
    );
  }
}

/// Wrapper widget that monitors for blocked apps and shows blocking screen
class AppBlockingWrapper extends StatefulWidget {
  const AppBlockingWrapper({super.key});

  @override
  State<AppBlockingWrapper> createState() => _AppBlockingWrapperState();
}

class _AppBlockingWrapperState extends State<AppBlockingWrapper>
    with WidgetsBindingObserver {
  String? _blockedPackageName;
  bool _checkingPermission = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeBlocking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppBlockingService.stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came to foreground, check permission and blocked apps
      _recheckPermission();
      // Check immediately when app resumes
      _checkCurrentApp();
      // Also check after a short delay to catch apps that just opened
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkCurrentApp();
        }
      });
    }
  }

  Future<void> _recheckPermission() async {
    if (!Platform.isAndroid) return;

    bool hasPermission = await AppBlockingService.hasPermission();
    if (hasPermission != _hasPermission) {
      setState(() {
        _hasPermission = hasPermission;
      });
      if (hasPermission) {
        _startMonitoring();
      }
    }
  }

  Future<void> _initializeBlocking() async {
    if (Platform.isAndroid) {
      bool hasUsagePermission = await AppBlockingService.hasPermission();
      bool hasOverlayPermission = await AppBlockingService.hasOverlayPermission();
      
      setState(() {
        _hasPermission = hasUsagePermission && hasOverlayPermission;
        _checkingPermission = false;
      });

      if (hasUsagePermission && hasOverlayPermission) {
        _startMonitoring();
      } else {
        // Request permissions
        if (!hasUsagePermission) {
          await _requestPermission();
        }
        if (!hasOverlayPermission) {
          await AppBlockingService.requestOverlayPermission();
        }
      }
    } else {
      setState(() {
        _checkingPermission = false;
      });
    }
  }

  Future<void> _requestPermission() async {
    await AppBlockingService.requestPermission();
    // Check again after requesting
    bool hasPermission = await AppBlockingService.hasPermission();
    setState(() {
      _hasPermission = hasPermission;
    });
    if (hasPermission) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    AppBlockingService.startMonitoring((blockedPackage) {
      if (mounted) {
        // Use a post-frame callback to ensure safe state updates
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _blockedPackageName = blockedPackage;
            });
          }
        });
      }
    });
  }

  Future<void> _checkCurrentApp() async {
    if (!Platform.isAndroid) return;

    String? currentApp = await AppBlockingService.getCurrentForegroundApp();
    if (currentApp == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];

    if (blockedApps.contains(currentApp) && mounted) {
      setState(() {
        _blockedPackageName = currentApp;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show blocking screen if a blocked app is detected
    if (_blockedPackageName != null) {
      return BlockedScreen(
        blockedPackageName: _blockedPackageName!,
        onUnblocked: () {
          setState(() {
            _blockedPackageName = null;
          });
        },
      );
    }

    // Show permission request screen if needed
    if (_checkingPermission) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPermission && Platform.isAndroid) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.white),
                const SizedBox(height: 32),
                const Text(
                  'Permission Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app needs Usage Access permission to monitor and block apps.',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Grant Permission',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _recheckPermission,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Check Again',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show home screen
    return const HomeScreen();
  }
}

// First screen with circular QUIT button
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AppsSelectionScreen(),
                ),
              );
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
              // Display the asset image in the circle, instead of Text('QUIT'):
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
          ),
          onEnter: (_) {},
          onExit: (_) {},
        ),
      ),
    );
  }
}

// Now a stateful widget to manage blocked apps set
class AppsSelectionScreen extends StatefulWidget {
  const AppsSelectionScreen({super.key});

  @override
  State<AppsSelectionScreen> createState() => _AppsSelectionScreenState();
}

class _AppsSelectionScreenState extends State<AppsSelectionScreen> {
  Set<String> _blockedApps = {};
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
  }

  Future<void> _loadBlockedApps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('blocked_apps') ?? [];
    setState(() {
      _blockedApps = list.toSet();
      _loadingPrefs = false;
    });
  }

  Future<void> _toggleAppBlocked(String packageName, bool blocked) async {
    setState(() {
      if (blocked) {
        _blockedApps.add(packageName);
      } else {
        _blockedApps.remove(packageName);
      }
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('blocked_apps', _blockedApps.toList());
  }

  @override
  Widget build(BuildContext context) {
    // Wait for prefs to load before building
    if (_loadingPrefs) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Select Apps to Block')),
      body: FutureBuilder(
        future: AppService.getApps(), // platform-specific
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final apps = snapshot.data as List<AppInfo>;
          return ListView.builder(
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              final isBlocked = _blockedApps.contains(app.packageName);
              return ListTile(
                leading: app.icon != null
                    ? Image.memory(
                        app.icon!,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.add_card,
                            color: Colors.white,
                          );
                        },
                      )
                    : const Icon(Icons.device_unknown, color: Colors.white),
                title: Text(
                  app.name,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: Switch(
                  value: isBlocked,
                  onChanged: (value) {
                    _toggleAppBlocked(app.packageName, value);
                  },
                  activeThumbColor: Colors.redAccent,
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
