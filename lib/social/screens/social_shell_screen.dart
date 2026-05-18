import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
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

    final tabs = <Widget>[
      const AppsSelectionScreen(),
      const WebsitesSelectionScreen(),
      const StatsTab(),
      const SocialHubScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('QUIT'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: tabs[index],
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
