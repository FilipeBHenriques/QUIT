import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/controllers/auth_controller.dart';
import '../controllers/timer_state_controller.dart';
import '../models/friendship.dart';
import '../models/notification_item.dart';
import '../models/transfer.dart';
import '../models/wallet_snapshot.dart';
import '../services/social_service.dart';
import '../services/sync_service.dart';
import '../services/wallet_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService(ref.watch(supabaseClientProvider));
});

final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService(ref.watch(supabaseClientProvider));
});

final syncServiceProvider = FutureProvider<SyncService>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return SyncService(ref.watch(walletServiceProvider), prefs);
});

final timerStateControllerProvider = FutureProvider<TimerStateController>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  final controller = TimerStateController(prefs);
  ref.onDispose(controller.dispose);
  await controller.loadFromStorage();
  return controller;
});

final friendsProvider = FutureProvider<List<Friendship>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(socialServiceProvider).listFriends();
});

final incomingRequestsProvider = FutureProvider<List<Transfer>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(socialServiceProvider).listIncomingRequests();
});

final outgoingRequestsProvider = FutureProvider<List<Transfer>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(socialServiceProvider).listOutgoingRequests();
});

final activityFeedProvider = FutureProvider<List<Transfer>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(socialServiceProvider).activity();
});

final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(socialServiceProvider).notifications();
});

final walletProvider = FutureProvider<WalletSnapshot>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(walletServiceProvider).getWallet();
});

final transferLimitsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(authControllerProvider);
  return ref.watch(walletServiceProvider).getTransferLimits();
});

final realtimeBootstrapProvider = Provider<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final uid = client.auth.currentUser?.id;
  if (uid == null) return;

  final subs = <RealtimeChannel>[];

  void invalidateAll() {
    ref.invalidate(friendsProvider);
    ref.invalidate(incomingRequestsProvider);
    ref.invalidate(outgoingRequestsProvider);
    ref.invalidate(activityFeedProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(walletProvider);
  }

  final walletChannel = client.channel('wallet-$uid')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'time_wallets',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
      callback: (_) => ref.invalidate(walletProvider),
    )
    ..subscribe();
  subs.add(walletChannel);

  final socialChannel = client.channel('social-$uid')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'friendships',
      callback: (_) => invalidateAll(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'time_transfers',
      callback: (_) => invalidateAll(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notifications',
      callback: (_) => ref.invalidate(notificationsProvider),
    )
    ..subscribe();
  subs.add(socialChannel);

  ref.onDispose(() {
    for (final sub in subs) {
      client.removeChannel(sub);
    }
  });
});
