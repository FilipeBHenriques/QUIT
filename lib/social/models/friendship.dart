enum FriendshipStatus { pending, accepted, blocked }

class Friendship {
  const Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.friendProfile,
  });

  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendshipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? friendProfile;

  factory Friendship.fromJson(Map<String, dynamic> json) {
    final statusText = (json['status'] as String? ?? 'pending').toLowerCase();
    return Friendship(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      addresseeId: json['addressee_id'] as String,
      status: FriendshipStatus.values.firstWhere(
        (s) => s.name == statusText,
        orElse: () => FriendshipStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      friendProfile: json['friend_profile'] as Map<String, dynamic>?,
    );
  }
}
