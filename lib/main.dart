import 'dart:io';

import 'package:flutter/material.dart' as flutter;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/controllers/auth_controller.dart';
import 'auth/screens/auth_gate_screen.dart';
import 'core/app_env.dart';
import 'game_result.dart';
import 'screens/blackjack_screen.dart';
import 'screens/blocked_screen.dart';
import 'screens/gamble_screen.dart';
import 'screens/game_result_screen.dart';
import 'screens/mines_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/roulette_screen.dart';
import 'social/screens/social_shell_screen.dart';
import 'social/services/cloud_state_service.dart';
import 'social/services/push_notification_service.dart';

const _permissionsChannel = MethodChannel('com.quit.app/permissions');

Future<bool> _hasAllRequiredPermissions() async {
  if (!Platform.isAndroid) return true;
  try {
    final result = await _permissionsChannel.invokeMapMethod<String, bool>('checkAll');
    if (result == null || result.isEmpty) return true;
    return (result['usageStats'] ?? false) &&
        (result['accessibility'] ?? false) &&
        (result['overlay'] ?? false);
  } catch (_) {
    return true;
  }
}

Future<void> main() async {
  flutter.WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MobileAds.instance.initialize();

  await Supabase.initialize(
    url: AppEnv.supabaseUrl,
    anonKey: AppEnv.supabaseAnonKey,
  );

  await _initializeServicesOnLaunch();
  await PushNotificationService.instance.initialize();
  await PushNotificationService.instance.registerCurrentToken();
  runApp(const ProviderScope(child: QuitApp()));
}

Future<void> _initializeServicesOnLaunch() async {
  try {
    final client = Supabase.instance.client;
    if (client.auth.currentUser != null) {
      await CloudStateService(client).hydrateLocalCacheFromCloud();
    }

    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    const platform = MethodChannel('com.quit.app/monitoring');

    final blockedApps = prefs.getStringList('blocked_apps') ?? <String>[];
    final blockedWebsites = prefs.getStringList('blocked_websites') ?? <String>[];

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
  } catch (_) {}
}

final _routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authControllerProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final auth = ref.read(authControllerProvider);
      final atAuth = state.matchedLocation == '/auth';
      final atPermissions = state.matchedLocation == '/permissions';

      if (auth.loading) return null;
      if (!auth.isAuthenticated && !atAuth) return '/auth';
      if (auth.isAuthenticated && atAuth) return '/';

      if (auth.isAuthenticated) {
        final hasPermissions = await _hasAllRequiredPermissions();
        if (!hasPermissions && !atPermissions) return '/permissions';
        if (hasPermissions && atPermissions) return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthGateScreen()),
      GoRoute(path: '/', builder: (_, __) => const SocialShellScreen()),
      GoRoute(path: '/blocked', builder: (_, __) => const BlockedScreen()),
      GoRoute(
        path: '/first_time_gamble',
        builder: (context, state) {
          final params = state.uri.queryParameters;
          return FirstTimeGambleScreen(
            packageName: params['packageName'] ?? '',
            appName: params['appName'] ?? '',
            retryBetSeconds: int.tryParse(params['retryBet'] ?? '') ?? 0,
          );
        },
      ),
      GoRoute(path: '/blackjack', builder: (_, __) => const BlackjackScreen()),
      GoRoute(path: '/roulette', builder: (_, __) => const RouletteScreen()),
      GoRoute(path: '/mines', builder: (_, __) => const MinesScreen()),
      GoRoute(path: '/permissions', builder: (_, __) => const PermissionsScreen()),
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
  );
});

class QuitApp extends ConsumerWidget {
  const QuitApp({super.key});

  @override
  flutter.Widget build(flutter.BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return ShadcnApp.router(
      theme: ThemeData(colorScheme: LegacyColorSchemes.darkZinc(), radius: 0.7),
      routerConfig: router,
    );
  }
}
