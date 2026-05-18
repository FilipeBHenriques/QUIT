import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/social_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: notifications.when(
          data: (items) {
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 220),
                Center(child: Text('No notifications yet.')),
              ]);
            }

            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final n = items[index];
                return ListTile(
                  leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active),
                  title: Text(n.type),
                  subtitle: Text(n.createdAt.toLocal().toString()),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e'))]),
        ),
      ),
    );
  }
}
