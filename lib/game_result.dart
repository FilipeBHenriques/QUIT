// lib/models/game_result.dart

/// Generic result model for all gambling games
class GameResult {
  final bool won;
  final int timeChange; // Seconds won (+) or lost (-)
  final String gameName;
  final String resultMessage;

  GameResult({
    required this.won,
    required this.timeChange,
    required this.gameName,
    this.resultMessage = '',
  });

  /// Formatted time change string (e.g., "+30s" or "-60s")
  String get timeChangeFormatted {
    final sign = timeChange >= 0 ? '+' : '';
    return '$sign${timeChange}s';
  }

  /// Time change in MM:SS format
  String get timeChangeFormattedMinutes {
    final abs = timeChange.abs();
    final minutes = abs ~/ 60;
    final seconds = abs % 60;
    final sign = timeChange >= 0 ? '+' : '-';
    return '$sign$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Color for the result (green for win, red for loss)
  bool get isPositive => timeChange >= 0;

  @override
  String toString() {
    return 'GameResult(won: $won, timeChange: $timeChange, game: $gameName)';
  }
}
