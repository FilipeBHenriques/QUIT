import 'package:flutter_test/flutter_test.dart';
import 'package:quit/social/models/transfer.dart';

void main() {
  test('Transfer.fromJson maps request_approved and status', () {
    final transfer = Transfer.fromJson({
      'id': '1',
      'sender_id': 'a',
      'receiver_id': 'b',
      'seconds': 120,
      'type': 'request_approved',
      'status': 'completed',
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
    });

    expect(transfer.type, TransferType.requestApproved);
    expect(transfer.status, TransferStatus.completed);
    expect(transfer.seconds, 120);
  });
}
