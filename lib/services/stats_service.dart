import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GameSession {
  final String gameName;
  final bool won;
  final int timeBetSeconds;
  final int timePayoutSeconds; // full time returned on wins, 0 on losses
  final int timeResultSeconds; // positive = won, negative = lost
  final int timestampMs;
  final String appPackage;
  final String appName;

  GameSession({
    required this.gameName,
    required this.won,
    required this.timeBetSeconds,
    required this.timePayoutSeconds,
    required this.timeResultSeconds,
    required this.timestampMs,
    required this.appPackage,
    required this.appName,
  });

  Map<String, dynamic> toJson() => {
    'gameName': gameName,
    'won': won,
    'timeBetSeconds': timeBetSeconds,
    'timePayoutSeconds': timePayoutSeconds,
    'timeResultSeconds': timeResultSeconds,
    'timestampMs': timestampMs,
    'appPackage': appPackage,
    'appName': appName,
  };

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
    gameName: json['gameName'] as String,
    won: json['won'] as bool,
    timeBetSeconds: json['timeBetSeconds'] as int,
    timePayoutSeconds:
        (json['timePayoutSeconds'] as int?) ??
        ((json['won'] as bool) ? (json['timeBetSeconds'] as int) + ((json['timeResultSeconds'] as int) > 0 ? (json['timeResultSeconds'] as int) : 0) : 0),
    timeResultSeconds: json['timeResultSeconds'] as int,
    timestampMs: json['timestampMs'] as int,
    appPackage: (json['appPackage'] as String?) ?? '',
    appName: (json['appName'] as String?) ?? '',
  );
}

class StatsService {
  static const _sessionsKey = 'game_sessions_v1';
  static const _maxSessions = 500;

  static Future<void> recordSession(GameSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sessionsKey) ?? [];
    raw.add(jsonEncode(session.toJson()));
    final trimmed = raw.length > _maxSessions
        ? raw.sublist(raw.length - _maxSessions)
        : raw;
    await prefs.setStringList(_sessionsKey, trimmed);
  }

  /// Remove the most recently recorded session. Used when a retry voids the
  /// preceding loss — that loss should not appear in stats at all.
  static Future<void> removeLastSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sessionsKey) ?? [];
    if (raw.isEmpty) return;
    raw.removeLast();
    await prefs.setStringList(_sessionsKey, raw);
  }

  static Future<List<GameSession>> getAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_sessionsKey) ?? [];
    return raw
        .map((s) => GameSession.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  // ── Derived stats ──────────────────────────────────────────────────────────

  static StatsSnapshot computeSnapshot(List<GameSession> sessions) {
    if (sessions.isEmpty) return StatsSnapshot.empty();

    final totalGames = sessions.length;
    final wins = sessions.where((s) => s.won).length;
    final losses = totalGames - wins;
    final winRate = totalGames > 0 ? wins / totalGames : 0.0;

    int totalWonSeconds = 0;
    int totalLostSeconds = 0;
    for (final s in sessions) {
      if (s.won) {
        totalWonSeconds += s.timePayoutSeconds; // bet returned + profit
      } else {
        totalLostSeconds += s.timeBetSeconds;   // amount staked and lost
      }
    }
    final netSeconds = totalWonSeconds - totalLostSeconds;

    // Per-game breakdown
    final Map<String, _GameAccum> byGame = {};
    for (final s in sessions) {
      byGame.putIfAbsent(s.gameName, () => _GameAccum());
      byGame[s.gameName]!.add(s);
    }
    final gameStats = byGame.entries.map((e) => GameStat(
      name: e.key,
      played: e.value.played,
      wins: e.value.wins,
      netSeconds: e.value.netSeconds,
    )).toList()..sort((a, b) => b.played.compareTo(a.played));

    // Current win streak
    int streak = 0;
    for (final s in sessions.reversed) {
      if (s.won) {
        streak++;
      } else {
        break;
      }
    }

    // Best game (highest win rate, min 3 plays)
    final eligible = gameStats.where((g) => g.played >= 3).toList();
    GameStat? bestGame;
    if (eligible.isNotEmpty) {
      eligible.sort((a, b) => b.winRate.compareTo(a.winRate));
      bestGame = eligible.first;
    }

    // Luckiest session (biggest single win)
    GameSession? biggestWin;
    int biggestWinVal = 0;
    for (final s in sessions) {
      if (s.won && s.timePayoutSeconds > biggestWinVal) {
        biggestWinVal = s.timePayoutSeconds;
        biggestWin = s;
      }
    }

    // Recent 10 sessions for history list
    final recent = sessions.reversed.take(10).toList();

    // Per-app usage (aggregated from sessions that had an app package)
    final Map<String, _AppAccum> byApp = {};
    for (final s in sessions) {
      if (s.appPackage.isEmpty) continue;
      byApp.putIfAbsent(s.appPackage, () => _AppAccum(s.appName));
      byApp[s.appPackage]!.add(s);
    }
    final appUsage = byApp.entries.map((e) => AppUsageStat(
      appPackage: e.key,
      appName: e.value.appName.isNotEmpty ? e.value.appName : e.key,
      attempts: e.value.attempts,
      wins: e.value.wins,
      losses: e.value.losses,
      netSeconds: e.value.netSeconds,
    )).toList()..sort((a, b) => b.attempts.compareTo(a.attempts));

    return StatsSnapshot(
      totalGames: totalGames,
      wins: wins,
      losses: losses,
      winRate: winRate,
      totalWonSeconds: totalWonSeconds,
      totalLostSeconds: totalLostSeconds,
      netSeconds: netSeconds,
      gameStats: gameStats,
      currentStreak: streak,
      bestGame: bestGame,
      biggestWin: biggestWin,
      recentSessions: recent,
      appUsage: appUsage,
    );
  }
}

class _GameAccum {
  int played = 0;
  int wins = 0;
  int netSeconds = 0;
  void add(GameSession s) {
    played++;
    if (s.won) wins++;
    netSeconds += s.timeResultSeconds;
  }
}

class _AppAccum {
  final String appName;
  int attempts = 0;
  int wins = 0;
  int losses = 0;
  int netSeconds = 0;
  _AppAccum(this.appName);
  void add(GameSession s) {
    attempts++;
    if (s.won) { wins++; } else { losses++; }
    netSeconds += s.timeResultSeconds;
  }
}

class GameStat {
  final String name;
  final int played;
  final int wins;
  final int netSeconds;

  GameStat({
    required this.name,
    required this.played,
    required this.wins,
    required this.netSeconds,
  });

  double get winRate => played > 0 ? wins / played : 0.0;
  int get losses => played - wins;
}

class AppUsageStat {
  final String appPackage;
  final String appName;
  final int attempts; // number of times blocked → led to a gamble
  final int wins;
  final int losses;
  final int netSeconds;

  AppUsageStat({
    required this.appPackage,
    required this.appName,
    required this.attempts,
    required this.wins,
    required this.losses,
    required this.netSeconds,
  });
}

class StatsSnapshot {
  final int totalGames;
  final int wins;
  final int losses;
  final double winRate;
  final int totalWonSeconds;
  final int totalLostSeconds;
  final int netSeconds;
  final List<GameStat> gameStats;
  final int currentStreak;
  final GameStat? bestGame;
  final GameSession? biggestWin;
  final List<GameSession> recentSessions;
  final List<AppUsageStat> appUsage;

  StatsSnapshot({
    required this.totalGames,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.totalWonSeconds,
    required this.totalLostSeconds,
    required this.netSeconds,
    required this.gameStats,
    required this.currentStreak,
    required this.bestGame,
    required this.biggestWin,
    required this.recentSessions,
    required this.appUsage,
  });

  factory StatsSnapshot.empty() => StatsSnapshot(
    totalGames: 0,
    wins: 0,
    losses: 0,
    winRate: 0,
    totalWonSeconds: 0,
    totalLostSeconds: 0,
    netSeconds: 0,
    gameStats: [],
    currentStreak: 0,
    bestGame: null,
    biggestWin: null,
    recentSessions: [],
    appUsage: [],
  );

  bool get isEmpty => totalGames == 0;
}
