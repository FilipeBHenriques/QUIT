import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/friendship.dart';
import '../providers/social_providers.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    final social = ref.watch(socialServiceProvider);
    final queryController = TextEditingController();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: queryController,
                  decoration: const InputDecoration(labelText: 'Friend user id'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  if (queryController.text.trim().isEmpty) return;
                  await social.sendFriendRequest(queryController.text.trim());
                  ref.invalidate(friendsProvider);
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: friends.when(
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('No friends yet.'));
              }

              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final item = list[i];
                  final statusColor = switch (item.status) {
                    FriendshipStatus.pending => Colors.amber,
                    FriendshipStatus.accepted => Colors.green,
                    FriendshipStatus.blocked => Colors.red,
                  };
                  final recentlyActive =
                      DateTime.now().difference(item.updatedAt).inMinutes < 15;
                  final liveChip = recentlyActive ? 'online' : 'recent';

                  return ListTile(
                    title: Text(item.id),
                    subtitle: Text('${item.requesterId} -> ${item.addresseeId}'),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(label: Text(item.status.name), backgroundColor: statusColor.withValues(alpha: 0.2)),
                        Chip(label: Text(liveChip)),
                        if (item.status == FriendshipStatus.pending)
                          IconButton(
                            onPressed: () async {
                              await social.acceptFriendRequest(item.id);
                              ref.invalidate(friendsProvider);
                            },
                            icon: const Icon(Icons.check_circle_outline),
                          ),
                        IconButton(
                          onPressed: () async {
                            await social.blockFriendship(item.id);
                            ref.invalidate(friendsProvider);
                          },
                          icon: const Icon(Icons.block),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
          ),
        ),
      ],
    );
  }
}
