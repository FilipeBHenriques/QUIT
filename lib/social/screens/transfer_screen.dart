import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/social_providers.dart';

class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen> {
  final TextEditingController _target = TextEditingController();
  final TextEditingController _seconds = TextEditingController(text: '300');
  final TextEditingController _memo = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final limits = ref.watch(transferLimitsProvider);
    final social = ref.watch(socialServiceProvider);
    final walletService = ref.watch(walletServiceProvider);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        wallet.when(
          data: (w) => Text('Available: ${w.balanceSeconds}s', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        limits.when(
          data: (l) => Text('Daily remaining: ${l['daily_remaining_seconds'] ?? '--'}s  | Cooldown: ${l['cooldown_seconds'] ?? '--'}s'),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        TextField(controller: _target, decoration: const InputDecoration(labelText: 'Friend User ID')),
        const SizedBox(height: 8),
        TextField(controller: _seconds, decoration: const InputDecoration(labelText: 'Seconds'), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [60, 300, 600, 900].map((v) => ActionChip(label: Text('${v}s'), onPressed: () => _seconds.text = '$v')).toList(),
        ),
        const SizedBox(height: 8),
        TextField(controller: _memo, decoration: const InputDecoration(labelText: 'Memo (optional)')),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: () async {
            final sec = int.tryParse(_seconds.text.trim()) ?? 0;
            if (_target.text.trim().isEmpty || sec <= 0) return;
            await walletService.sendTimeGift(toUserId: _target.text.trim(), seconds: sec, memo: _memo.text.trim().isEmpty ? null : _memo.text.trim());
            final sync = await ref.read(syncServiceProvider.future);
            await sync.forceSync();
            ref.invalidate(walletProvider);
            ref.invalidate(activityFeedProvider);
          },
          child: const Text('Send Time'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            final sec = int.tryParse(_seconds.text.trim()) ?? 0;
            if (_target.text.trim().isEmpty || sec <= 0) return;
            await social.requestTime(fromUserId: _target.text.trim(), seconds: sec, memo: _memo.text.trim().isEmpty ? null : _memo.text.trim());
            ref.invalidate(outgoingRequestsProvider);
          },
          child: const Text('Request Time'),
        ),
      ],
    );
  }
}
