import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'screens/blocked_screen.dart';
import 'screens/gamble_screen.dart';
import 'screens/apps_tab.dart';
import 'screens/websites_tab.dart';
import 'screens/blackjack_screen.dart';
import 'screens/roulette_screen.dart';
import 'screens/mines_screen.dart';
import 'package:go_router/go_router.dart';
import 'widgets/game_card.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeServicesOnLaunch();
  runApp(const QuitApp());
}

Future<void> _initializeServicesOnLaunch() async {
  if (!Platform.isAndroid) return;

  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();

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
      const platform = MethodChannel('com.quit.app/monitoring');
      await platform.invokeMethod('updateBlockedWebsites', {
        'blockedWebsites': blockedWebsites,
      });
      print(
        '🌐 [LAUNCH] Website monitoring synced: ${blockedWebsites.length} sites',
      );
    }
  } catch (e) {
    print('❌ [LAUNCH] Error initializing services: $e');
  }
}

class QuitApp extends StatelessWidget {
  const QuitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadcnApp.router(
      darkTheme: ThemeData(colorScheme: ColorSchemes.darkGreen, radius: 0.7),
      theme: ThemeData(colorScheme: ColorSchemes.darkGreen, radius: 0.7),

      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/blocked',
            builder: (context, state) => const BlockedScreen(),
          ),
          GoRoute(
            path: '/first_time_gamble',
            builder: (context, state) => const FirstTimeGambleScreen(),
          ),
          GoRoute(
            path: '/blackjack',
            builder: (context, state) => const BlackjackScreen(),
          ),
          GoRoute(
            path: '/roulette',
            builder: (context, state) => const RouletteScreen(),
          ),
          GoRoute(
            path: '/mines',
            builder: (context, state) => const MinesScreen(),
          ),
          GoRoute(
            path: '/blocking_selection',
            builder: (context, state) => const BlockingSelectionScreen(),
          ),
        ],
      ),
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
      _syncServicesIfNeeded();
    }
  }

  Future<void> _syncServicesIfNeeded() async {
    if (!Platform.isAndroid) return;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

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
        await platform.invokeMethod('updateBlockedWebsites', {
          'blockedWebsites': blockedWebsites,
        });
        print(
          '🌐 [RESUME] Updated website monitoring: ${blockedWebsites.length} sites',
        );
      }
    } catch (e) {
      print('❌ [RESUME] Error syncing services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            OutlineButton(
              onPressed: () async {
                await context.push('/blocking_selection');
                _syncServicesIfNeeded();
              },
              density: ButtonDensity.icon,
              child: const Icon(LucideIcons.shieldBan),
            ),
            // Game buttons - PURE SHADCN
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                GameCard(
                  icon: LucideIcons.spade,
                  label: 'Blackjack',
                  variant: GameCardVariant.primary,
                  onClick: () => context.push('/blackjack'),
                ),
                GameCard(
                  icon: LucideIcons.disc,
                  label: 'Roulette',
                  variant: GameCardVariant.destructive,
                  onClick: () => context.push('/roulette'),
                ),
                GameCard(
                  icon: LucideIcons.grid3x3,
                  label: 'Mines',
                  variant: GameCardVariant.success,
                  onClick: () => context.push('/mines'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BlockingSelectionScreen extends StatefulWidget {
  const BlockingSelectionScreen({super.key});

  @override
  State<BlockingSelectionScreen> createState() =>
      _BlockingSelectionScreenState();
}

class _BlockingSelectionScreenState extends State<BlockingSelectionScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: const Text('Block Apps & Websites'),
          leading: [
            OutlineButton(
              onPressed: () => context.pop(),
              density: ButtonDensity.icon,
              child: const Icon(LucideIcons.arrowLeft),
            ),
          ],
        ),
        const Divider(),
      ],
      child: Column(
        children: [
          Tabs(
            index: _index,
            onChanged: (index) {
              setState(() {
                _index = index;
              });
            },
            children: const [
              TabItem(child: Text('Apps')),
              TabItem(child: Text('Websites')),
            ],
          ),
          const Divider(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                AppsSelectionScreen(),
                WebsitesSelectionScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
