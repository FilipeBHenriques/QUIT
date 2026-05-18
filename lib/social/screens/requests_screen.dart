import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/social_providers.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on PostgrestException catch (e) {
      if (!context.mounted) return;
      final msg = e.message.toLowerCase().contains('insufficient balance')
          ? 'Not enough available time to approve this request.'
          : 'Request failed: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingRequestsProvider);
    final outgoing = ref.watch(outgoingRequestsProvider);
    final wallet = ref.watch(walletProvider);
    final social = ref.watch(socialServiceProvider);
    final walletBalance = wallet.maybeWhen(
      data: (w) => w.balanceSeconds,
      orElse: () => -1,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(incomingRequestsProvider);
        ref.invalidate(outgoingRequestsProvider);
      },
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Incoming', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          incoming.when(
            data: (list) => Column(
              children: list
                  .map(
                    (r) {
                      final insufficient =
                          walletBalance >= 0 && walletBalance < r.seconds;
                      return Card(
                      child: ListTile(
                        title: Text('${r.seconds}s requested'),
                        subtitle: Text(
                          insufficient
                              ? 'from ${r.senderUsername ?? r.senderId}  •  not enough balance'
                              : 'from ${r.senderUsername ?? r.senderId}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
                              onPressed: insufficient ? null : () async {
                                await _runAction(context, () => social.approveRequest(r.id));
                                ref.invalidate(incomingRequestsProvider);
                                ref.invalidate(walletProvider);
                              },
                              icon: const Icon(Icons.check),
                            ),
                            IconButton(
                              onPressed: () async {
                                await _runAction(context, () => social.declineRequest(r.id));
                                ref.invalidate(incomingRequestsProvider);
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                    );
                    },
                  )
                  .toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(12), child: Text(e.toString())),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Outgoing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          outgoing.when(
            data: (list) => Column(
              children: list
                  .map(
                    (r) => Card(
                      child: ListTile(
                        title: Text('${r.seconds}s requested'),
                        subtitle: Text('to ${r.receiverUsername ?? r.receiverId}'),
                        trailing: IconButton(
                          onPressed: () async {
                            await _runAction(context, () => social.cancelRequest(r.id));
                            ref.invalidate(outgoingRequestsProvider);
                          },
                          icon: const Icon(Icons.cancel_outlined),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(12), child: Text(e.toString())),
          ),
        ],
      ),
    );
  }
}
