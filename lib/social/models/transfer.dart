enum TransferType { gift, request, requestApproved }
enum TransferStatus { pending, approved, declined, completed, canceled }

class Transfer {
  const Transfer({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.seconds,
    required this.type,
    required this.status,
    required this.createdAt,
    this.memo,
    this.requestTransferId,
    this.senderUsername,
    this.receiverUsername,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final int seconds;
  final TransferType type;
  final TransferStatus status;
  final DateTime createdAt;
  final String? memo;
  final String? requestTransferId;
  final String? senderUsername;
  final String? receiverUsername;

  factory Transfer.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String? ?? 'gift').toLowerCase();
    final type = switch (rawType) {
      'request' => TransferType.request,
      'request_approved' => TransferType.requestApproved,
      _ => TransferType.gift,
    };

    final rawStatus = (json['status'] as String? ?? 'pending').toLowerCase();
    final status = switch (rawStatus) {
      'approved' => TransferStatus.approved,
      'declined' => TransferStatus.declined,
      'completed' => TransferStatus.completed,
      'canceled' => TransferStatus.canceled,
      _ => TransferStatus.pending,
    };

    return Transfer(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      seconds: json['seconds'] as int,
      type: type,
      status: status,
      createdAt: DateTime.parse(json['created_at'] as String),
      memo: json['memo'] as String?,
      requestTransferId: json['request_transfer_id'] as String?,
      senderUsername: (json['sender_profile'] as Map<String, dynamic>?)?['username'] as String?,
      receiverUsername: (json['receiver_profile'] as Map<String, dynamic>?)?['username'] as String?,
    );
  }
}
