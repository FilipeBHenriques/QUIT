class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.payload,
    required this.createdAt,
    required this.read,
  });

  final String id;
  final String recipientId;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final bool read;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      type: json['type'] as String,
      payload: (json['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      createdAt: DateTime.parse(json['created_at'] as String),
      read: json['read'] as bool? ?? false,
    );
  }
}
