class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final String id;
  final String username;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime lastSeenAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String? ?? 'User',
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
    );
  }
}
