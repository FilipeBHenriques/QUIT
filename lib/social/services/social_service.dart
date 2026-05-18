import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friendship.dart';
import '../models/transfer.dart';
import '../models/notification_item.dart';

class SocialService {
  SocialService(this._client);

  final SupabaseClient _client;

  Future<List<Friendship>> listFriends() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('friendships')
        .select(
          'id, requester_id, addressee_id, status, created_at, updated_at,'
          'requester:profiles!friendships_requester_id_fkey(id,username,avatar_url),'
          'addressee:profiles!friendships_addressee_id_fkey(id,username,avatar_url)',
        )
        .or('requester_id.eq.$uid,addressee_id.eq.$uid')
        .order('updated_at', ascending: false);
    return (rows as List).map((raw) {
      final row = (raw as Map<String, dynamic>);
      final requesterId = row['requester_id'] as String;
      final requester = row['requester'] as Map<String, dynamic>?;
      final addressee = row['addressee'] as Map<String, dynamic>?;
      final isRequester = requesterId == uid;
      final friendProfile = isRequester ? addressee : requester;
      final normalized = Map<String, dynamic>.from(row)
        ..['friend_profile'] = friendProfile;
      return Friendship.fromJson(normalized);
    }).toList();
  }

  Future<void> sendFriendRequest(String userId) async {
    await _client.rpc('send_friend_request', params: {'p_target_user_id': userId});
  }

  Future<void> acceptFriendRequest(String friendshipId) async {
    await _client.rpc('accept_friend_request', params: {'p_friendship_id': friendshipId});
  }

  Future<void> blockFriendship(String friendshipId) async {
    await _client.from('friendships').update({'status': 'blocked'}).eq('id', friendshipId);
  }

  Future<void> removeFriendship(String friendshipId) async {
    await _client.from('friendships').delete().eq('id', friendshipId);
  }

  Future<List<Transfer>> listIncomingRequests() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('time_transfers')
        .select(
          '*,'
          'sender_profile:profiles!time_transfers_sender_id_fkey(id,username,avatar_url),'
          'receiver_profile:profiles!time_transfers_receiver_id_fkey(id,username,avatar_url)',
        )
        .eq('receiver_id', uid)
        .eq('type', 'request')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Transfer.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Transfer>> listOutgoingRequests() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('time_transfers')
        .select(
          '*,'
          'sender_profile:profiles!time_transfers_sender_id_fkey(id,username,avatar_url),'
          'receiver_profile:profiles!time_transfers_receiver_id_fkey(id,username,avatar_url)',
        )
        .eq('sender_id', uid)
        .eq('type', 'request')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => Transfer.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> requestTime({required String fromUserId, required int seconds, String? memo}) async {
    await _client.rpc('request_time', params: {
      'p_from_user_id': fromUserId,
      'p_seconds': seconds,
      'p_memo': memo,
    });
  }

  Future<void> approveRequest(String requestTransferId) async {
    await _client.rpc('approve_time_request', params: {
      'p_request_transfer_id': requestTransferId,
    });
  }

  Future<void> declineRequest(String requestTransferId) async {
    await _client.rpc('decline_time_request', params: {
      'p_request_transfer_id': requestTransferId,
    });
  }

  Future<void> cancelRequest(String requestTransferId) async {
    await _client.rpc('cancel_time_request', params: {
      'p_request_transfer_id': requestTransferId,
    });
  }

  Future<List<Transfer>> activity({int limit = 50}) async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('time_transfers')
        .select(
          '*,'
          'sender_profile:profiles!time_transfers_sender_id_fkey(id,username,avatar_url),'
          'receiver_profile:profiles!time_transfers_receiver_id_fkey(id,username,avatar_url)',
        )
        .or('sender_id.eq.$uid,receiver_id.eq.$uid')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((row) => Transfer.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<NotificationItem>> notifications() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', uid)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((row) => NotificationItem.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
