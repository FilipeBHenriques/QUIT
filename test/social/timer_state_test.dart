import 'package:flutter_test/flutter_test.dart';
import 'package:quit/social/controllers/timer_state_controller.dart';

void main() {
  test('TimerState copyWith updates selected fields', () {
    final base = TimerState(
      remainingSeconds: 60,
      dailyLimitSeconds: 3600,
      bonusAvailable: false,
      lastTickAt: DateTime.utc(2026, 1, 1),
      dirty: false,
    );

    final updated = base.copyWith(remainingSeconds: 30, dirty: true);

    expect(updated.remainingSeconds, 30);
    expect(updated.dailyLimitSeconds, 3600);
    expect(updated.dirty, true);
  });
}
