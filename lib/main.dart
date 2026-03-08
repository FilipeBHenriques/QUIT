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
    with
        flutter.WidgetsBindingObserver,
        flutter.SingleTickerProviderStateMixin {
  static const platform = MethodChannel('com.quit.app/monitoring');
  late final flutter.AnimationController _qGlowController;

  @override
  void initState() {
    super.initState();
    flutter.WidgetsBinding.instance.addObserver(this);
    _qGlowController = flutter.AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _qGlowController.dispose();
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
      child: flutter.Container(
        decoration: const flutter.BoxDecoration(
          gradient: flutter.LinearGradient(
            begin: flutter.Alignment.topCenter,
            end: flutter.Alignment.bottomCenter,
            colors: [
              flutter.Color(0xFF06090F),
              flutter.Color(0xFF0B1220),
              flutter.Color(0xFF05070B),
            ],
          ),
        ),
        child: flutter.Center(
          child: flutter.Column(
            mainAxisAlignment: flutter.MainAxisAlignment.center,
            children: [
              flutter.GestureDetector(
                onTap: () async {
                  await context.push('/blocking_selection');
                  _syncServicesIfNeeded();
                },
                child: flutter.AnimatedBuilder(
                  animation: _qGlowController,
                  builder: (context, _) {
                    final t = _qGlowController.value;
                    final pulse = 0.96 + (t * 0.08);
                    final ringGlow = 0.18 + (t * 0.34);
                    final textGlow = 0.38 + (t * 0.5);
                    return flutter.Transform.scale(
                      scale: pulse,
                      child: flutter.Container(
                        width: 190,
                        height: 190,
                        alignment: flutter.Alignment.center,
                        decoration: flutter.BoxDecoration(
                          shape: flutter.BoxShape.circle,
                          boxShadow: [
                            flutter.BoxShadow(
                              color: const flutter.Color(
                                0xFFFFFFFF,
                              ).withOpacity(ringGlow),
                              blurRadius: 56,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: flutter.Text(
                          'Q',
                          style: flutter.TextStyle(
                            color: const flutter.Color(0xFFFFFFFF),
                            fontSize: 122,
                            fontWeight: flutter.FontWeight.w700,
                            shadows: [
                              flutter.Shadow(
                                color: const flutter.Color(
                                  0xFFFFFFFF,
                                ).withOpacity(textGlow),
                                blurRadius: 34,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
          const flutter.SizedBox(height: 10),
          Padding(
            padding: const flutter.EdgeInsets.symmetric(horizontal: 24),
            child: flutter.Container(
              child: flutter.Row(
                children: [
                  flutter.Expanded(
                    child: _TopSelectorItem(
                      selected: _index == 0,
                      icon: LucideIcons.grid3x3,
                      label: 'Apps',
                      onTap: () => setState(() => _index = 0),
                    ),
                  ),
                  flutter.Expanded(
                    child: _TopSelectorItem(
                      selected: _index == 1,
                      icon: LucideIcons.globe,
                      label: 'Websites',
                      onTap: () => setState(() => _index = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const flutter.SizedBox(height: 8),
          flutter.Expanded(
            child: _index == 0
                ? const AppsSelectionScreen()
                : const WebsitesSelectionScreen(),
          ),
        ],
      ),
    );
  }
}

class _TopSelectorItem extends flutter.StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final flutter.VoidCallback onTap;

  const _TopSelectorItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return flutter.GestureDetector(
      onTap: onTap,
      child: flutter.AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const flutter.EdgeInsets.only(top: 16, bottom: 10),
        decoration: flutter.BoxDecoration(
          borderRadius: flutter.BorderRadius.circular(12),
        ),
        child: flutter.Column(
          mainAxisSize: flutter.MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? const flutter.Color(0xFFFFFFFF)
                  : const flutter.Color(0xFF8B95A7),
            ),
            const flutter.SizedBox(height: 8),
            flutter.Text(
              label,
              style: flutter.TextStyle(
                color: selected
                    ? const flutter.Color(0xFFFFFFFF)
                    : const flutter.Color(0xFF8B95A7),
                fontSize: 16,
                fontWeight: flutter.FontWeight.w500,
              ),
            ),
            const flutter.SizedBox(height: 12),
            flutter.AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 3,
              width: selected ? 120 : 0,
              decoration: flutter.BoxDecoration(
                color: const flutter.Color.fromARGB(255, 255, 0, 0),
                borderRadius: flutter.BorderRadius.circular(999),
                boxShadow: [
                  flutter.BoxShadow(
                    color: const flutter.Color(0xFFFF2D8F).withOpacity(0.45),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
