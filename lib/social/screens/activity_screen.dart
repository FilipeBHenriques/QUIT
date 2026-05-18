import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/social_providers.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityFeedProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(activityFeedProvider),
      child: activity.when(
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, i) {
            final t = items[i];
            return ListTile(
              leading: Icon(
                t.type.name == 'gift' ? Icons.card_giftcard : Icons.swap_horiz,
              ),
              title: Text('${t.type.name} ${t.seconds}s'),
              subtitle: Text(
                '${t.senderUsername ?? t.senderId} -> ${t.receiverUsername ?? t.receiverId}',
              ),
              trailing: Text(t.status.name),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(12), child: Text(e.toString()))]),
      ),
    );
  }
}
