import 'package:flutter/widgets.dart' as flutter;
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'screens/blocked_screen.dart';
import 'screens/gamble_screen.dart';
import 'screens/apps_tab.dart';
import 'screens/websites_tab.dart';
import 'screens/blackjack_screen.dart';
import 'screens/roulette_screen.dart';
import 'screens/mines_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/game_result_screen.dart';
import 'game_result.dart';
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
    const platform = MethodChannel('com.quit.app/monitoring');

    final List<String> blockedApps = prefs.getStringList('blocked_apps') ?? [];
    final List<String> blockedWebsites =
        prefs.getStringList('blocked_websites') ?? [];

    if (blockedApps.isNotEmpty) {
      await platform.invokeMethod('startMonitoring', {
        'blockedApps': blockedApps,
      });
      if (blockedWebsites.isNotEmpty) {
        await platform.invokeMethod('updateBlockedWebsites', {
          'blockedWebsites': blockedWebsites,
        });
      }
    }
  } catch (e) {
    // Silently ignore — service may not be running yet.
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
          GoRoute(
            path: '/permissions',
            builder: (context, state) => const PermissionsScreen(),
          ),
          GoRoute(
            path: '/game_result',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return GameResultScreen(
                result: extra['result'] as GameResult,
                packageName: extra['packageName'] as String,
                appName: extra['appName'] as String,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HOME SCREEN
// ============================================================================

class HomeScreen extends flutter.StatefulWidget {
  const HomeScreen({super.key});

  @override
  flutter.State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends flutter.State<HomeScreen>
    with
        flutter.WidgetsBindingObserver,
        flutter.TickerProviderStateMixin {
  static const platform = MethodChannel('com.quit.app/monitoring');
  static const _platform = MethodChannel('com.quit.app/permissions');
  late final flutter.AnimationController _waveController;
  bool? _permissionsOk;
  bool _hasAutoNavigated = false;

  @override
  void initState() {
    super.initState();
    _waveController = flutter.AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    flutter.WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    _waveController.dispose();
    flutter.WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(flutter.AppLifecycleState state) {
    if (state == flutter.AppLifecycleState.resumed) {
      _checkPermissions();
      _syncServicesIfNeeded();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final result = await _platform.invokeMapMethod<String, bool>('checkAll');
      if (!mounted) return;
      final ok = result?.values.every((v) => v) ?? false;
      setState(() => _permissionsOk = ok);
      if (!ok && !_hasAutoNavigated) {
        _hasAutoNavigated = true;
        flutter.WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.push('/permissions');
        });
      }
    } catch (_) {
      if (mounted) setState(() => _permissionsOk = true);
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
      }

      List<String> blockedWebsites =
          prefs.getStringList('blocked_websites') ?? [];
      if (blockedWebsites.isNotEmpty) {
        await platform.invokeMethod('updateBlockedWebsites', {
          'blockedWebsites': blockedWebsites,
        });
      }
    } catch (_) {}
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    return Scaffold(
      child: flutter.GestureDetector(
        behavior: flutter.HitTestBehavior.opaque,
        onTap: () async {
          await context.push('/blocking_selection');
          _syncServicesIfNeeded();
        },
        child: flutter.Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const flutter.BoxDecoration(
            gradient: flutter.LinearGradient(
              begin: flutter.Alignment.topCenter,
              end: flutter.Alignment.bottomCenter,
              colors: [
                flutter.Color(0xFF04050C),
                flutter.Color(0xFF020408),
                flutter.Color(0xFF030408),
              ],
            ),
          ),
          child: flutter.Stack(
            children: [
              // Background grid
              flutter.CustomPaint(
                painter: _GridPainter(),
                size: flutter.Size.infinite,
              ),

              flutter.SafeArea(
                child: flutter.SizedBox.expand(
                  child: flutter.Stack(
                    alignment: flutter.Alignment.center,
                    children: [

                      // ── Centered main content ──
                      flutter.Column(
                        mainAxisSize: flutter.MainAxisSize.min,
                        crossAxisAlignment: flutter.CrossAxisAlignment.center,
                        children: [
                          // QUIT letter tiles — white traveling wave
                          flutter.AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, _) {
                              const letters = ['Q', 'U', 'I', 'T'];
                              const white = flutter.Color(0xFFFFFFFF);
                              return flutter.Row(
                                mainAxisSize: flutter.MainAxisSize.min,
                                children: List.generate(letters.length, (i) {
                                  final g = (math.sin(_waveController.value * 2 * math.pi - i * math.pi / 2) + 1) / 2;
                                  return flutter.Container(
                                    margin: const flutter.EdgeInsets.symmetric(horizontal: 5),
                                    width: 68,
                                    height: 74,
                                    decoration: flutter.BoxDecoration(
                                      color: const flutter.Color(0xFF080A12),
                                      borderRadius: flutter.BorderRadius.circular(10),
                                      border: flutter.Border.all(
                                        color: white.withValues(alpha: 0.10 + g * 0.55),
                                        width: 0.5,
                                      ),
                                      boxShadow: [
                                        flutter.BoxShadow(
                                          color: white.withValues(alpha: g * 0.18),
                                          blurRadius: 20,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    alignment: flutter.Alignment.center,
                                    child: flutter.Text(
                                      letters[i],
                                      style: flutter.TextStyle(
                                        fontSize: 36,
                                        fontWeight: flutter.FontWeight.w800,
                                        color: flutter.Color.lerp(
                                          const flutter.Color(0xFF3A4055),
                                          const flutter.Color(0xFFFFFFFF),
                                          g,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),

                          const flutter.SizedBox(height: 32),

                          // Thin rule
                          flutter.Container(
                            width: 200,
                            height: 0.5,
                            color: const flutter.Color(0xFF1C2030),
                          ),

                          const flutter.SizedBox(height: 20),

                          // TAP TO CONFIGURE — fades with wave
                          flutter.AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, _) {
                              final t = _waveController.value;
                              final opacity = 0.28 + (t > 0.5 ? (1 - t) : t) * 0.32;
                              return flutter.Text(
                                'TAP TO CONFIGURE',
                                style: flutter.TextStyle(
                                  color: const flutter.Color(0xFFFFFFFF).withValues(alpha: opacity),
                                  fontSize: 9,
                                  fontWeight: flutter.FontWeight.w700,
                                  letterSpacing: 4,
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      // ── Bottom content (pinned) ──
                      flutter.Positioned(
                        bottom: 28,
                        left: 0,
                        right: 0,
                        child: flutter.Column(
                          mainAxisSize: flutter.MainAxisSize.min,
                          crossAxisAlignment: flutter.CrossAxisAlignment.center,
                          children: [
                            if (_permissionsOk == false) ...[
                              flutter.GestureDetector(
                                onTap: () => context.push('/permissions'),
                                child: flutter.Container(
                                  padding: const flutter.EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: flutter.BoxDecoration(
                                    color: const flutter.Color(0xFFFF1A5C).withValues(alpha: 0.08),
                                    borderRadius: flutter.BorderRadius.circular(20),
                                    border: flutter.Border.all(
                                      color: const flutter.Color(0xFFFF1A5C).withValues(alpha: 0.28),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: flutter.Row(
                                    mainAxisSize: flutter.MainAxisSize.min,
                                    children: [
                                      flutter.Icon(
                                        Icons.warning_amber_rounded,
                                        size: 11,
                                        color: const flutter.Color(0xFFFF1A5C),
                                      ),
                                      const flutter.SizedBox(width: 6),
                                      const flutter.Text(
                                        'PERMISSIONS NEEDED',
                                        style: flutter.TextStyle(
                                          color: flutter.Color(0xFFFF1A5C),
                                          fontSize: 9,
                                          fontWeight: flutter.FontWeight.w700,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const flutter.SizedBox(height: 14),
                            ],
                            const flutter.Text(
                              'FOCUSED LIVING',
                              style: flutter.TextStyle(
                                color: flutter.Color(0xFF2E3448),
                                fontSize: 10,
                                fontWeight: flutter.FontWeight.w700,
                                letterSpacing: 6,
                              ),
                            ),
                          ],
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Background grid painter
class _GridPainter extends flutter.CustomPainter {
  @override
  void paint(flutter.Canvas canvas, flutter.Size size) {
    final paint = flutter.Paint()
      ..color = const flutter.Color(0xFF14161E).withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(
        flutter.Offset(x, 0),
        flutter.Offset(x, size.height),
        paint,
      );
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(
        flutter.Offset(0, y),
        flutter.Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant flutter.CustomPainter oldDelegate) => false;
}


// ============================================================================
// BLOCKING SELECTION SCREEN
// ============================================================================

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
          const flutter.SizedBox(height: 8),
          Padding(
            padding: const flutter.EdgeInsets.symmetric(horizontal: 24),
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
          const flutter.SizedBox(height: 4),
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
    const neonRose = flutter.Color(0xFFFF1A5C);
    return flutter.GestureDetector(
      onTap: onTap,
      child: flutter.AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const flutter.EdgeInsets.only(top: 14, bottom: 10),
        decoration: flutter.BoxDecoration(
          borderRadius: flutter.BorderRadius.circular(12),
        ),
        child: flutter.Column(
          mainAxisSize: flutter.MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? const flutter.Color(0xFFFFFFFF)
                  : const flutter.Color(0xFF3D4558),
            ),
            const flutter.SizedBox(height: 8),
            flutter.Text(
              label,
              style: flutter.TextStyle(
                color: selected
                    ? const flutter.Color(0xFFFFFFFF)
                    : const flutter.Color(0xFF3D4558),
                fontSize: 15,
                fontWeight: flutter.FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const flutter.SizedBox(height: 10),
            flutter.AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: selected ? 100 : 0,
              decoration: flutter.BoxDecoration(
                color: neonRose,
                borderRadius: flutter.BorderRadius.circular(999),
                boxShadow: selected
                    ? [
                        flutter.BoxShadow(
                          color: neonRose.withValues(alpha: 0.55),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                        flutter.BoxShadow(
                          color: neonRose.withValues(alpha: 0.22),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
