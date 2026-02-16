import 'package:flutter/widgets.dart' as flutter;
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
  flutter.WidgetsFlutterBinding.ensureInitialized();
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

class QuitApp extends flutter.StatelessWidget {
  const QuitApp({super.key});

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return ShadcnApp.router(
      theme: ThemeData(colorScheme: LegacyColorSchemes.darkZinc(), radius: 0.7),
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/blocked',
            builder: (context, state) => const BlockedScreen(),
          ),
          GoRoute(
            path: '/first_time_gamble',
            builder: (context, state) {
              final params = state.uri.queryParameters;
              return FirstTimeGambleScreen(
                packageName: params['packageName'] ?? '',
                appName: params['appName'] ?? '',
              );
            },
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

class HomeScreen extends flutter.StatefulWidget {
  const HomeScreen({super.key});

  @override
  flutter.State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends flutter.State<HomeScreen>
    with flutter.WidgetsBindingObserver {
  static const platform = MethodChannel('com.quit.app/monitoring');

  @override
  void initState() {
    super.initState();
    flutter.WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    flutter.WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(flutter.AppLifecycleState state) {
    if (state == flutter.AppLifecycleState.resumed) {
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
  flutter.Widget build(flutter.BuildContext context) {
    return Scaffold(
      child: flutter.Center(
        child: flutter.Column(
          mainAxisAlignment: flutter.MainAxisAlignment.center,
          children: [
            const flutter.SizedBox(height: 40),
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

class BlockingSelectionScreen extends flutter.StatefulWidget {
  const BlockingSelectionScreen({super.key});

  @override
  flutter.State<BlockingSelectionScreen> createState() =>
      _BlockingSelectionScreenState();
}

class _BlockingSelectionScreenState
    extends flutter.State<BlockingSelectionScreen> {
  int _index = 0;

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return Scaffold(
      headers: [
        AppBar(
          title: const flutter.Text('Block Apps & Websites'),
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
      child: flutter.Column(
        children: [
          Tabs(
            index: _index,
            onChanged: (index) {
              setState(() {
                _index = index;
              });
            },
            children: const [
              TabItem(child: flutter.Text('Apps')),
              TabItem(child: flutter.Text('Websites')),
            ],
          ),
          const Divider(),
          flutter.Expanded(
            child: flutter.IndexedStack(
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
