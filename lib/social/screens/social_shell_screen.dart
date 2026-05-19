import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../screens/apps_tab.dart';
import '../../screens/stats_screen.dart';
import '../../screens/websites_tab.dart';
import '../providers/social_providers.dart';
import 'social_hub_screen.dart';

class SocialShellScreen extends ConsumerStatefulWidget {
  const SocialShellScreen({super.key});

  @override
  ConsumerState<SocialShellScreen> createState() => _SocialShellScreenState();
}

class _SocialShellScreenState extends ConsumerState<SocialShellScreen>
    with WidgetsBindingObserver {
  int index = 0;
  Timer? _heartbeatTimer;
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = const <Widget>[
      AppsSelectionScreen(),
      WebsitesSelectionScreen(),
      StatsTab(),
      SocialHubScreen(),
    ];
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runHeartbeatTick();
      ref.invalidate(walletProvider);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _runHeartbeatTick();
    });
  }

  Future<void> _runHeartbeatTick() async {
    final prefs = await SharedPreferences.getInstance();
    final guestMode = prefs.getBool('guest_mode') ?? false;
    if (guestMode) return;
    try {
      await ref.read(authServiceProvider).updateLastSeen();
      final sync = await ref.read(syncServiceProvider.future);
      await sync.syncWalletIfDirty();
    } catch (_) {
      // Ignore transient auth/session errors during lifecycle heartbeats.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(realtimeBootstrapProvider);
    final auth = ref.watch(authControllerProvider);
    final tabs = <Widget>[
      _tabs[0],
      _tabs[1],
      _tabs[2],
      auth.isAuthenticated ? _tabs[3] : const _ConnectAccountTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('QUIT'),
        actions: [
          if (auth.isAuthenticated)
            IconButton(
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
            )
          else
            IconButton(
              onPressed: () => context.push('/auth'),
              icon: const Icon(Icons.login),
            ),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.apps), label: 'Apps'),
          NavigationDestination(icon: Icon(Icons.language), label: 'Web'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Social'),
        ],
      ),
    );
  }
}

class _ConnectAccountTab extends StatelessWidget {
  const _ConnectAccountTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 48, color: Colors.white70),
            const SizedBox(height: 12),
            const Text(
              'Connect an account to use Friends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Social transfers, requests, and friend activity require Google sign-in.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/auth'),
              child: const Text('Connect with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
