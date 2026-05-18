import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../theme/neon_palette.dart';
import '../../widgets/neon_button.dart';
import '../models/friendship.dart';
import '../models/transfer.dart';
import '../providers/social_providers.dart';

class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen> {
  final TextEditingController _username = TextEditingController();
  final TextEditingController _friendSearch = TextEditingController();
  final TextEditingController _seconds = TextEditingController(text: '300');
  final TextEditingController _memo = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _busy = false;
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = <Map<String, dynamic>>[];
  String? _usernameInitFromProfileId;

  int _tabIndex = 0;

  String _short(String id) => id.length <= 8 ? id : '${id.substring(0, 8)}...';

  String _fmtDuration(int totalSeconds) {
    final s = totalSeconds < 0 ? 0 : totalSeconds;
    final d = s ~/ 86400;
    final h = (s % 86400) ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    final parts = <String>[];
    if (d > 0) parts.add('${d}d');
    if (h > 0 || d > 0) parts.add('${h}h');
    if (m > 0 || h > 0 || d > 0) parts.add('${m}m');
    parts.add('${sec}s');
    return parts.join(' ');
  }

  String _requestStateLabel(Transfer t) {
    if (t.type == TransferType.request) {
      if (t.status == TransferStatus.pending) return 'pending';
      if (t.status == TransferStatus.declined ||
          t.status == TransferStatus.canceled) {
        return 'ignored';
      }
      if (t.status == TransferStatus.approved) return 'accepted';
    }
    if (t.type == TransferType.requestApproved) return 'accepted';
    return t.status.name;
  }

  Future<void> _safeAction(Future<void> Function() run) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await run();
      ref.invalidate(friendsProvider);
      ref.invalidate(incomingRequestsProvider);
      ref.invalidate(outgoingRequestsProvider);
      ref.invalidate(activityFeedProvider);
      ref.invalidate(walletProvider);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = (e.message.toLowerCase().contains('insufficient balance'))
          ? 'Not enough available time to approve this request.'
          : 'Action failed: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: NeonPalette.rose),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e'), backgroundColor: NeonPalette.rose),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _searchProfiles() async {
    final q = _friendSearch.text.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = <Map<String, dynamic>>[]);
      return;
    }
    setState(() => _searching = true);
    try {
      final rows = await Supabase.instance.client.rpc(
        'search_profiles',
        params: {'p_query': q, 'p_limit': 8},
      );
      if (!mounted) return;
      setState(
        () => _searchResults = (rows as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _searchResults = <Map<String, dynamic>>[]);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Search failed: $e'),
          backgroundColor: NeonPalette.rose,
        ),
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final authService = ref.read(authServiceProvider);
      await _safeAction(() async {
        await authService.updateAvatar(bytes);
        await ref.read(authControllerProvider.notifier).refreshProfile();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Avatar upload failed: $e')));
    }
  }

  Future<void> _actionDialog({
    required String title,
    required Future<void> Function(int seconds, String? memo) onConfirm,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NeonPalette.surface,
        title: Text(title, style: const TextStyle(color: NeonPalette.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _seconds,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: NeonPalette.text),
              decoration: _inputDecoration('Seconds'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memo,
              style: const TextStyle(color: NeonPalette.text),
              decoration: _inputDecoration('Memo (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final sec = int.tryParse(_seconds.text.trim()) ?? 0;
    if (sec <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seconds must be > 0'),
          backgroundColor: NeonPalette.rose,
        ),
      );
      return;
    }
    await _safeAction(() async {
      await onConfirm(
        sec,
        _memo.text.trim().isEmpty ? null : _memo.text.trim(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final authService = ref.watch(authServiceProvider);
    final social = ref.watch(socialServiceProvider);
    final wallet = ref.watch(walletServiceProvider);
    final walletAsync = ref.watch(walletProvider);
    final friendsAsync = ref.watch(friendsProvider);
    final incomingAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingRequestsProvider);
    final activityAsync = ref.watch(activityFeedProvider);

    final uid = Supabase.instance.client.auth.currentUser?.id;
    final profile = authState.profile;
    if (profile != null && _usernameInitFromProfileId != profile.id) {
      _username.text = profile.username;
      _usernameInitFromProfileId = profile.id;
    }
    final avatarUrl = profile?.avatarUrl ?? '';
    final walletBalance = walletAsync.maybeWhen(
      data: (w) => w.balanceSeconds,
      orElse: () => -1,
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF03050A), Color(0xFF070A12)],
        ),
      ),
      child: RefreshIndicator(
        color: NeonPalette.rose,
        backgroundColor: NeonPalette.surface,
        onRefresh: () async {
          ref.invalidate(friendsProvider);
          ref.invalidate(incomingRequestsProvider);
          ref.invalidate(outgoingRequestsProvider);
          ref.invalidate(activityFeedProvider);
          ref.invalidate(walletProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          children: [
            _header(walletAsync),
            const SizedBox(height: 12),
            _topTabs(),
            const SizedBox(height: 12),
            if (_tabIndex == 0)
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile & Settings',
                      style: TextStyle(
                        color: NeonPalette.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _busy ? null : _pickAndUploadAvatar,
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: NeonPalette.surfaceElevated,
                        backgroundImage: avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                        child: avatarUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                color: NeonPalette.textMuted,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _username,
                      style: const TextStyle(color: NeonPalette.text),
                      decoration: _inputDecoration('Username'),
                    ),
                    const SizedBox(height: 8),
                    NeonButton(
                      onPressed: _busy
                          ? null
                          : () => _safeAction(() async {
                              await authService.updateUsername(_username.text);
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .refreshProfile();
                            }),
                      text: 'Save Username',
                      color: NeonPalette.surfaceSoft,
                      borderColor: NeonPalette.borderBright,
                      textColor: NeonPalette.text,
                      glowColor: NeonPalette.rose,
                      glowOpacity: 0.12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                  ],
                ),
              ),
            if (_tabIndex == 1) ...[
              _card(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _friendSearch,
                            style: const TextStyle(color: NeonPalette.text),
                            decoration: _inputDecoration('Search username'),
                            onSubmitted: (_) => _searchProfiles(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 86,
                          child: NeonButton(
                            onPressed: _searching ? null : _searchProfiles,
                            text: _searching ? '...' : 'Add',
                            color: NeonPalette.rose.withValues(alpha: 0.10),
                            borderColor: NeonPalette.rose.withValues(
                              alpha: 0.35,
                            ),
                            textColor: NeonPalette.rose,
                            glowColor: NeonPalette.rose,
                            glowOpacity: 0.18,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_searchResults.isNotEmpty) const SizedBox(height: 8),
                    ..._searchResults.map((u) {
                      final name = (u['username'] as String?) ?? 'User';
                      final id = (u['id'] as String?) ?? '';
                      final avatar = (u['avatar_url'] as String?) ?? '';
                      return _rowTile(
                        title: name,
                        subtitle: _short(id),
                        avatarUrl: avatar,
                        trailing: SizedBox(
                          width: 80,
                          child: NeonButton(
                            onPressed: _busy
                                ? null
                                : () => _safeAction(() async {
                                    await social.sendFriendRequest(id);
                                  }),
                            text: 'Add',
                            color: NeonPalette.surfaceSoft,
                            borderColor: NeonPalette.borderBright,
                            textColor: NeonPalette.text,
                            glowColor: NeonPalette.rose,
                            glowOpacity: 0.12,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 9,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: friendsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(
                      child: CircularProgressIndicator(color: NeonPalette.rose),
                    ),
                  ),
                  error: (e, _) => Text(
                    e.toString(),
                    style: const TextStyle(color: NeonPalette.rose),
                  ),
                  data: (friends) {
                    final accepted = friends
                        .where((f) => f.status == FriendshipStatus.accepted)
                        .toList();
                    final pendingForMe = friends
                        .where(
                          (f) =>
                              f.status == FriendshipStatus.pending &&
                              f.addresseeId == uid,
                        )
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Friends List',
                          style: TextStyle(
                            color: NeonPalette.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (pendingForMe.isNotEmpty)
                          ...pendingForMe.map((f) {
                            final name =
                                (f.friendProfile?['username'] as String?) ??
                                _short(f.requesterId);
                            final avatar =
                                (f.friendProfile?['avatar_url'] as String?) ??
                                '';
                            return _rowTile(
                              title: name,
                              subtitle: 'Pending friend request',
                              avatarUrl: avatar,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _miniAction(
                                    icon: Icons.check,
                                    onTap: _busy
                                        ? null
                                        : () => _safeAction(() async {
                                            await social.acceptFriendRequest(
                                              f.id,
                                            );
                                          }),
                                  ),
                                  const SizedBox(width: 8),
                                  _miniAction(
                                    icon: Icons.close,
                                    onTap: _busy
                                        ? null
                                        : () => _safeAction(() async {
                                            await social.removeFriendship(f.id);
                                          }),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ...accepted.map((f) {
                          final friendId = f.requesterId == uid
                              ? f.addresseeId
                              : f.requesterId;
                          final friendName =
                              (f.friendProfile?['username'] as String?) ??
                              _short(friendId);
                          final avatar =
                              (f.friendProfile?['avatar_url'] as String?) ?? '';
                          return _rowTile(
                            title: friendName,
                            subtitle: 'Friend',
                            avatarUrl: avatar,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _miniAction(
                                  icon: Icons.north_east_rounded,
                                  onTap: _busy
                                      ? null
                                      : () => _actionDialog(
                                          title: 'Send Time to $friendName',
                                          onConfirm: (sec, memo) =>
                                              wallet.sendTimeGift(
                                                toUserId: friendId,
                                                seconds: sec,
                                                memo: memo,
                                              ),
                                        ),
                                ),
                                const SizedBox(width: 8),
                                _miniAction(
                                  icon: Icons.south_west_rounded,
                                  onTap: _busy
                                      ? null
                                      : () => _actionDialog(
                                          title:
                                              'Request Time from $friendName',
                                          onConfirm: (sec, memo) =>
                                              social.requestTime(
                                                fromUserId: friendId,
                                                seconds: sec,
                                                memo: memo,
                                              ),
                                        ),
                                ),
                                const SizedBox(width: 8),
                                _miniAction(
                                  icon: Icons.person_remove_alt_1_rounded,
                                  onTap: _busy
                                      ? null
                                      : () => _safeAction(() async {
                                          await social.removeFriendship(f.id);
                                        }),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (accepted.isEmpty && pendingForMe.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No friends yet.',
                              style: TextStyle(color: NeonPalette.textMuted),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
            if (_tabIndex == 2) ...[
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Incoming Requests',
                      style: TextStyle(
                        color: NeonPalette.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    incomingAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => Text(
                        e.toString(),
                        style: const TextStyle(color: NeonPalette.rose),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return const Text(
                            'No incoming requests.',
                            style: TextStyle(color: NeonPalette.textMuted),
                          );
                        }
                        return Column(
                          children: list.map((r) {
                            final insufficient =
                                walletBalance >= 0 && walletBalance < r.seconds;
                            return _rowTile(
                              title: '${_fmtDuration(r.seconds)} requested',
                              subtitle:
                                  insufficient
                                      ? 'from ${r.senderUsername ?? _short(r.senderId)}  pending  not enough balance'
                                      : 'from ${r.senderUsername ?? _short(r.senderId)}  pending',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _miniAction(
                                    icon: Icons.check,
                                    onTap: _busy || insufficient
                                        ? null
                                        : () => _safeAction(() async {
                                            await social.approveRequest(r.id);
                                          }),
                                  ),
                                  const SizedBox(width: 8),
                                  _miniAction(
                                    icon: Icons.close,
                                    onTap: _busy
                                        ? null
                                        : () => _safeAction(() async {
                                            await social.declineRequest(r.id);
                                          }),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Outgoing Requests',
                      style: TextStyle(
                        color: NeonPalette.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    outgoingAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => Text(
                        e.toString(),
                        style: const TextStyle(color: NeonPalette.rose),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return const Text(
                            'No outgoing requests.',
                            style: TextStyle(color: NeonPalette.textMuted),
                          );
                        }
                        return Column(
                          children: list.map((r) {
                            return _rowTile(
                              title: '${_fmtDuration(r.seconds)} requested',
                              subtitle:
                                  'to ${r.receiverUsername ?? _short(r.receiverId)}  pending',
                              trailing: _miniAction(
                                icon: Icons.cancel_outlined,
                                onTap: _busy
                                    ? null
                                    : () => _safeAction(() async {
                                        await social.cancelRequest(r.id);
                                      }),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transfer History',
                      style: TextStyle(
                        color: NeonPalette.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    activityAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => Text(
                        e.toString(),
                        style: const TextStyle(color: NeonPalette.rose),
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return const Text(
                            'No transfer activity yet.',
                            style: TextStyle(color: NeonPalette.textMuted),
                          );
                        }
                        return Column(
                          children: list.take(20).map((t) {
                            final fromName =
                                t.senderUsername ?? _short(t.senderId);
                            final toName =
                                t.receiverUsername ?? _short(t.receiverId);
                            return _rowTile(
                              title:
                                  '${t.type.name}  ${_fmtDuration(t.seconds)}',
                              subtitle:
                                  '$fromName -> $toName  ${_requestStateLabel(t)}',
                              trailing: const Icon(
                                Icons.history_rounded,
                                color: NeonPalette.textMuted,
                                size: 18,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _topTabs() {
    final tabs = const ['Profile', 'Friends', 'History'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NeonPalette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonPalette.borderBright, width: 0.6),
      ),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? NeonPalette.rose.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: active
                      ? Border.all(
                          color: NeonPalette.rose.withValues(alpha: 0.35),
                          width: 0.6,
                        )
                      : null,
                ),
                child: Text(
                  tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? NeonPalette.text : NeonPalette.textMuted,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _header(AsyncValue<dynamic> walletAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: NeonPalette.rose.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: NeonPalette.rose.withValues(alpha: 0.35),
                width: 0.7,
              ),
            ),
            child: const Icon(
              Icons.group_rounded,
              color: NeonPalette.rose,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Social',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: NeonPalette.text,
                  ),
                ),
                walletAsync.when(
                  data: (w) => Text(
                    'Wallet ${_fmtDuration(w.balanceSeconds)}',
                    style: const TextStyle(
                      color: NeonPalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  loading: () => const Text(
                    'Wallet syncing...',
                    style: TextStyle(
                      color: NeonPalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  error: (err, stack) => const Text(
                    'Wallet unavailable',
                    style: TextStyle(
                      color: NeonPalette.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: child,
    );
  }

  Widget _rowTile({
    required String title,
    required String subtitle,
    required Widget trailing,
    String? avatarUrl,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: NeonPalette.surfaceSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonPalette.border, width: 0.6),
      ),
      child: Row(
        children: [
          if (avatarUrl != null && avatarUrl.isNotEmpty) ...[
            CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(avatarUrl),
              backgroundColor: NeonPalette.surfaceElevated,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: NeonPalette.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: NeonPalette.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }

  Widget _miniAction({required IconData icon, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: NeonPalette.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: NeonPalette.borderBright, width: 0.6),
        ),
        child: Icon(icon, color: NeonPalette.text, size: 17),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: NeonPalette.textMuted),
      isDense: true,
      filled: true,
      fillColor: NeonPalette.surfaceSoft,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NeonPalette.border, width: 0.7),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NeonPalette.border, width: 0.7),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NeonPalette.rose, width: 0.9),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [NeonPalette.surface, NeonPalette.surfaceSoft],
      ),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: NeonPalette.borderBright, width: 0.65),
      boxShadow: [
        BoxShadow(
          color: NeonPalette.rose.withValues(alpha: 0.08),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ],
    );
  }
}
