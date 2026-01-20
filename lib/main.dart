import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/blocked_screen.dart';
import 'screens/gamble_screen.dart';
import 'screens/apps_tab.dart';
import 'screens/websites_tab.dart';
import 'screens/blackjack_screen.dart';
import 'screens/roulette_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start services immediately on app launch
  await _initializeServicesOnLaunch();

  runApp(const QuitApp());
}

// Initialize services ONCE on app launch
Future<void> _initializeServicesOnLaunch() async {
  if (!Platform.isAndroid) return;

  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Start app monitoring
    List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
    if (blockedApps.isNotEmpty) {
      const platform = MethodChannel('com.quit.app/monitoring');
      await platform.invokeMethod('startMonitoring', {
        'blockedApps': blockedApps,
      });
      print('🚀 [LAUNCH] App monitoring started: ${blockedApps.length} apps');
    }

    List<String> blockedWebsites =
        prefs.getStringList('blocked_websites') ?? [];
    if (blockedWebsites.isNotEmpty) {
      bool instantBlock = prefs.getBool('instant_block_websites') ?? true;
      bool shouldBlock = instantBlock;

      if (!instantBlock) {
        // Timer mode: check if time ran out
        int dailyLimit = prefs.getInt('daily_limit_seconds') ?? 0;
        int remaining = prefs.getInt('remaining_seconds') ?? dailyLimit;
        shouldBlock = dailyLimit == 0 || remaining <= 0;
      }
    }
  } catch (e) {
    print('❌ [LAUNCH] Error initializing services: $e');
  }
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
      routes: {
        '/blocked': (context) => const BlockedScreen(),
        '/first_time_gamble': (context) => const FirstTimeGambleScreen(),
      },
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Services should already be running from main()
      // Just sync state if needed
      _syncServicesIfNeeded();
    }
  }

  Future<void> _syncServicesIfNeeded() async {
    if (!Platform.isAndroid) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Update app monitoring
      List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
      if (blockedApps.isNotEmpty) {
        await platform.invokeMethod('updateBlockedApps', {
          'blockedApps': blockedApps,
        });
        print('🔄 [RESUME] Updated app monitoring: ${blockedApps.length} apps');
      }

      List<String> blockedWebsites =
          prefs.getStringList('blocked_websites') ?? [];
      if (blockedWebsites.isNotEmpty) {
        bool instantBlock = prefs.getBool('instant_block_websites') ?? true;
        bool shouldBlock = instantBlock;

        if (!instantBlock) {
          int dailyLimit = prefs.getInt('daily_limit_seconds') ?? 0;
          int remaining = prefs.getInt('remaining_seconds') ?? dailyLimit;
          shouldBlock = dailyLimit == 0 || remaining <= 0;
        }
      }
    } catch (e) {
      print('❌ [RESUME] Error syncing services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Main settings button
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BlockingSelectionScreen(),
                  ),
                );
                // Sync services when returning from settings
                _syncServicesIfNeeded();
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

            const SizedBox(height: 40),

            // Game buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Blackjack button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BlackjackScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.casino, size: 24),
                  label: const Text(
                    'Blackjack',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Roulette button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RouletteScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.album, size: 24),
                  label: const Text(
                    'Roulette',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// TABBED INTERFACE: Apps + Websites
class BlockingSelectionScreen extends StatefulWidget {
  const BlockingSelectionScreen({super.key});

  @override
  State<BlockingSelectionScreen> createState() =>
      _BlockingSelectionScreenState();
}

class _BlockingSelectionScreenState extends State<BlockingSelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Block Apps & Websites'),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.redAccent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.apps), text: 'Apps'),
            Tab(icon: Icon(Icons.language), text: 'Websites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [AppsSelectionScreen(), WebsitesSelectionScreen()],
      ),
    );
  }
}
