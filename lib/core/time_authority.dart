import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class TimeAuthority {
  static const String _keyAnchorWallMs = 'time_anchor_wall_ms';
  static const String _keyLastWallMs = 'time_last_wall_ms';

  static int effectiveNowMs(SharedPreferences prefs) {
    final wallNow = DateTime.now().millisecondsSinceEpoch;
    final anchorWall = prefs.getInt(_keyAnchorWallMs);
    final lastWall = prefs.getInt(_keyLastWallMs);

    if (anchorWall == null || lastWall == null) {
      prefs.setInt(_keyAnchorWallMs, wallNow);
      prefs.setInt(_keyLastWallMs, wallNow);
      return wallNow;
    }

    // Monotonic wall-clock fallback:
    // - Moves forward with normal wall time.
    // - Never moves backward if user rewinds device clock.
    final forwardDelta = max<int>(0, wallNow - lastWall);
    final effectiveNow = anchorWall + forwardDelta;

    prefs.setInt(_keyAnchorWallMs, effectiveNow);
    prefs.setInt(_keyLastWallMs, wallNow);
    return effectiveNow;
  }
}
