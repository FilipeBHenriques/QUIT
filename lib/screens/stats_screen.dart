import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:quit/services/stats_service.dart';
import 'package:quit/theme/neon_palette.dart';

const Color _kRose  = Color(0xFFFF1A5C);
const Color _kAmber = Color(0xFFFFAB00);

enum _Period { today, allTime }

// ─────────────────────────────────────────────────────────────────────────────

class StatsTab extends StatefulWidget {
  const StatsTab({super.key});
  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> with SingleTickerProviderStateMixin {

  // ── Core ───────────────────────────────────────────────────────────────────
  List<GameSession> _allSessions = [];
  List<String>      _blockedApps = [];
  List<String>      _blockedWebsites = [];
  Map<String, AppInfo> _appInfoCache = {};

  // ── Today (SharedPreferences) ──────────────────────────────────────────────
  int _limitSeconds     = 0;
  int _usedSeconds      = 0;
  int _remainingSeconds = 0;
  int _bonusSeconds     = 0;

  // ── Per-period app usage ───────────────────────────────────────────────────
  final Map<_Period, Map<String, int>> _usageCache   = {};
  final Map<_Period, bool>             _usageLoading = {
    _Period.today  : false,
    _Period.allTime: false,
  };

  // ── UI ─────────────────────────────────────────────────────────────────────
  _Period _period  = _Period.today;
  bool    _loading = true;
  Timer?  _refreshTimer;

  late AnimationController _ringCtrl;
  late Animation<double>   _ringAnim;

  // ── Derived ────────────────────────────────────────────────────────────────

  List<GameSession> get _sessions {
    if (_period == _Period.today) {
      final now    = DateTime.now();
      final cutoff = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      return _allSessions.where((s) => s.timestampMs >= cutoff).toList();
    }
    return _allSessions;
  }

  StatsSnapshot get _snap => StatsService.computeSnapshot(_sessions);
  Map<String, int> get _appUsage => _usageCache[_period] ?? {};

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300));
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);
    _loadAll();
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _refreshToday());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _ringCtrl.dispose();
    super.dispose();
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    _allSessions = await StatsService.getAllSessions();

    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final blockedApps     = prefs.getStringList('blocked_apps')     ?? [];
    final blockedWebsites = prefs.getStringList('blocked_websites') ?? [];
    final limit           = prefs.getInt('daily_limit_seconds') ?? 0;
    final used            = prefs.getInt('used_today_seconds')  ?? 0;
    final remaining       = prefs.getInt('remaining_seconds')   ?? 0;
    final bonus           = (used > limit && limit > 0) ? used - limit : 0;

    final Map<String, AppInfo> cache = {};
    for (final pkg in blockedApps) {
      try {
        final info = await InstalledApps.getAppInfo(pkg);
        if (info != null) cache[pkg] = info;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _blockedApps      = blockedApps;
      _blockedWebsites  = blockedWebsites;
      _appInfoCache     = cache;
      _limitSeconds     = limit;
      _usedSeconds      = used;
      _remainingSeconds = remaining;
      _bonusSeconds     = bonus;
      _loading          = false;
    });
    _ringCtrl.forward();
    _loadUsage(_Period.today);
  }

  Future<void> _loadUsage(_Period p) async {
    if (_usageLoading[p] == true || _usageCache.containsKey(p)) return;
    setState(() => _usageLoading[p] = true);

    Map<String, int> data;
    try {
      if (p == _Period.today) {
        data = await _eventsUsage();
      } else {
        final start = DateTime.now().subtract(const Duration(days: 365));
        final map   = await UsageStats.queryAndAggregateUsageStats(start, DateTime.now());
        data = {};
        for (final e in map.entries) {
          final ms = int.tryParse(e.value.totalTimeInForeground ?? '0') ?? 0;
          if (ms > 0) data[e.key] = ms ~/ 1000;
        }
      }
    } catch (_) { data = {}; }

    if (!mounted) return;
    setState(() { _usageCache[p] = data; _usageLoading[p] = false; });
  }

  Future<Map<String, int>> _eventsUsage() async {
    final now      = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day);
    final events   = await UsageStats.queryEvents(startDay, now);

    final Map<String, int> fgStart = {};
    final Map<String, int> total   = {};

    for (final e in events) {
      final pkg = e.packageName;
      if (pkg == null) continue;
      final ts = int.tryParse(e.timeStamp ?? '0') ?? 0;
      if (e.eventType == '1') {
        fgStart[pkg] = ts;
      } else if (e.eventType == '2') {
        final s = fgStart.remove(pkg);
        if (s != null && ts > s) total[pkg] = (total[pkg] ?? 0) + (ts - s);
      }
    }
    final nowMs = now.millisecondsSinceEpoch;
    for (final entry in fgStart.entries) {
      if (nowMs > entry.value) {
        total[entry.key] = (total[entry.key] ?? 0) + (nowMs - entry.value);
      }
    }
    return total.map((k, v) => MapEntry(k, v ~/ 1000));
  }

  Future<void> _refreshToday() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!mounted) return;
    final used      = prefs.getInt('used_today_seconds')  ?? 0;
    final remaining = prefs.getInt('remaining_seconds')   ?? 0;
    final limit     = prefs.getInt('daily_limit_seconds') ?? _limitSeconds;
    setState(() {
      _usedSeconds      = used;
      _remainingSeconds = remaining;
      _limitSeconds     = limit;
      _bonusSeconds     = (used > limit && limit > 0) ? used - limit : 0;
    });
    // Re-fetch today's usage
    _usageCache.remove(_Period.today);
    _usageLoading[_Period.today] = false;
    _loadUsage(_Period.today);
  }

  Future<void> _resetDebugData() async {
    final prefs = await SharedPreferences.getInstance();
    // Restore remaining time to daily limit so first-time gamble triggers
    final limit = prefs.getInt('daily_limit_seconds') ?? 0;
    await prefs.setInt('remaining_seconds', limit);
    await prefs.setInt('used_today_seconds', 0);
    await prefs.remove('game_sessions_v1');
    await prefs.remove('bonus_used_today_seconds');
    await prefs.remove('timer_last_reset');
    await prefs.remove('timer_first_choice_made');
    await prefs.remove('daily_time_ran_out_timestamp');
    await prefs.remove('last_bonus_time');
    // Reload everything
    _usageCache.clear();
    _usageLoading[_Period.today]   = false;
    _usageLoading[_Period.allTime] = false;
    await _loadAll();
  }

  void _selectPeriod(_Period p) {
    if (_period == p) return;
    setState(() => _period = p);
    _ringCtrl.forward(from: 0);
    _loadUsage(p);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _kRose, strokeWidth: 1.5));
    }

    final snap          = _snap;
    final pct           = (snap.winRate * 100).round();
    final ringColor     = snap.totalGames == 0 ? NeonPalette.textMuted
        : pct >= 50 ? NeonPalette.mint : _kRose;
    final isToday       = _period == _Period.today;
    final hasLimit      = _limitSeconds > 0 && isToday;
    final usedCapped    = hasLimit
        ? _usedSeconds.clamp(0, _limitSeconds) : _usedSeconds;
    final progress      = hasLimit
        ? (usedCapped / _limitSeconds).clamp(0.0, 1.0) : 0.0;
    final totalAppTime  = _blockedApps.fold(0,
        (sum, pkg) => sum + (_appUsage[pkg] ?? 0));
    final appLoading    = _usageLoading[_period] == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [

        // ── Period selector ──────────────────────────────────────────────────
        _buildPeriodSelector(),
        const SizedBox(height: 24),

        // ── SCREEN TIME ──────────────────────────────────────────────────────
        _label('SCREEN TIME'),
        const SizedBox(height: 10),
        _NeonCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              isToday ? _fmt(usedCapped) : _fmt(totalAppTime),
              style: const TextStyle(
                color: _kRose, fontSize: 40, fontWeight: FontWeight.w900, height: 1,
                shadows: [Shadow(color: Color(0x99FF1A5C), blurRadius: 24)])),
            const SizedBox(width: 7),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                isToday ? 'used today' : 'on blocked apps',
                style: const TextStyle(color: NeonPalette.textMuted, fontSize: 12))),
            const Spacer(),
            if (hasLimit) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt(_remainingSeconds.clamp(0, _limitSeconds)),
                  style: const TextStyle(color: NeonPalette.text,
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const Text('remaining',
                  style: TextStyle(color: NeonPalette.textMuted, fontSize: 10)),
            ]),
          ]),
          if (hasLimit) ...[
            const SizedBox(height: 14),
            _progressBar(progress),
            const SizedBox(height: 6),
            Text('${(progress * 100).round()}% of daily limit',
                style: const TextStyle(color: NeonPalette.textMuted, fontSize: 10)),
          ],
          if (_bonusSeconds > 0 && isToday) ...[
            const SizedBox(height: 10),
            _bonusPill(_bonusSeconds),
          ],
        ])),

        const SizedBox(height: 12),

        // ── Per-app breakdown ────────────────────────────────────────────────
        _label('BY APP'),
        const SizedBox(height: 8),
        if (appLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: _kRose, strokeWidth: 1.5)))
        else
          _buildAppList(),

        if (_blockedWebsites.isNotEmpty) ...[
          const SizedBox(height: 12),
          _label('BLOCKED WEBSITES'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _blockedWebsites.map((site) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kAmber.withValues(alpha: 0.22), width: 0.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.language_rounded, size: 11,
                    color: _kAmber.withValues(alpha: 0.7)),
                const SizedBox(width: 5),
                Text(site, style: const TextStyle(
                    color: _kAmber, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            )).toList(),
          ),
        ],

        const SizedBox(height: 24),

        // ── GAMBLING ─────────────────────────────────────────────────────────
        _label('GAMBLING'),
        const SizedBox(height: 10),
        _NeonCard(child: snap.totalGames == 0
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No games played yet',
                  style: TextStyle(color: NeonPalette.textMuted, fontSize: 13)))
            : Column(children: [

                // Ring + W/L/Total
                Row(children: [
                  AnimatedBuilder(
                    animation: _ringAnim,
                    builder: (_, _) => CustomPaint(
                      size: const Size(90, 90),
                      painter: _RingPainter(
                          progress: _ringAnim.value * snap.winRate,
                          color: ringColor),
                      child: SizedBox(width: 90, height: 90,
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('$pct%', style: TextStyle(
                            color: ringColor, fontSize: 22, fontWeight: FontWeight.w900,
                            shadows: [Shadow(
                                color: ringColor.withValues(alpha: 0.7), blurRadius: 14)])),
                          const Text('WIN', style: TextStyle(
                              color: NeonPalette.textMuted, fontSize: 9,
                              fontWeight: FontWeight.w700, letterSpacing: 2)),
                        ]))),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _statRow('WINS',   '${snap.wins}',       NeonPalette.mint),
                    const SizedBox(height: 7),
                    _statRow('LOSSES', '${snap.losses}',     _kRose),
                    const SizedBox(height: 7),
                    _statRow('TOTAL',  '${snap.totalGames}', NeonPalette.textMuted),
                  ])),
                ]),

                const SizedBox(height: 14),
                _divider(),
                const SizedBox(height: 14),

                // Earned / Lost / Net
                Row(children: [
                  _timeCell('+${_fmt(snap.totalWonSeconds)}',  'EARNED', NeonPalette.mint),
                  _vDivider(),
                  _timeCell('-${_fmt(snap.totalLostSeconds)}', 'LOST',   _kRose),
                  _vDivider(),
                  _timeCell(
                    '${snap.netSeconds >= 0 ? '+' : '-'}${_fmt(snap.netSeconds.abs())}',
                    'NET',
                    snap.netSeconds >= 0 ? NeonPalette.mint : _kRose),
                ]),

                if (snap.gameStats.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _divider(),
                  const SizedBox(height: 14),
                  ...snap.gameStats.map(_buildGameRow),
                ],
              ])),

        // ── Debug reset ──────────────────────────────────────────────────────
        const SizedBox(height: 32),
        GestureDetector(
          onTap: _resetDebugData,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: NeonPalette.border,
                width: 0.5,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded,
                    size: 13, color: NeonPalette.textMuted),
                SizedBox(width: 7),
                Text(
                  'RESET DEBUG DATA',
                  style: TextStyle(
                    color: NeonPalette.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Period selector ────────────────────────────────────────────────────────

  Widget _buildPeriodSelector() => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: NeonPalette.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: NeonPalette.borderBright, width: 0.5),
    ),
    child: Row(children: [
      _periodBtn('TODAY',    _Period.today),
      _periodBtn('ALL TIME', _Period.allTime),
    ]),
  );

  Widget _periodBtn(String label, _Period p) {
    final active = _period == p;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectPeriod(p),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _kRose.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active ? _kRose.withValues(alpha: 0.4) : Colors.transparent,
              width: 0.5),
          ),
          child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? _kRose : NeonPalette.textMuted,
              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2)),
        ),
      ),
    );
  }

  // ── App list ───────────────────────────────────────────────────────────────

  Widget _buildAppList() {
    if (_blockedApps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('No apps blocked yet.',
            style: const TextStyle(color: NeonPalette.textMuted, fontSize: 13)));
    }

    final usage  = _appUsage;
    final sorted = List<String>.from(_blockedApps)
      ..sort((a, b) => (usage[b] ?? 0).compareTo(usage[a] ?? 0));
    final maxSec = (usage[sorted.first] ?? 0).clamp(1, 999999999);

    return Column(
      children: sorted.map((pkg) {
        final info     = _appInfoCache[pkg];
        final name     = info?.name ?? pkg.split('.').last;
        final seconds  = usage[pkg] ?? 0;
        final bar      = (seconds / maxSec).clamp(0.0, 1.0);
        final hasUsage = seconds > 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: NeonPalette.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: NeonPalette.borderBright, width: 0.5),
            ),
            child: Row(children: [
              _AppIcon(info: info, size: 36),
              const SizedBox(width: 11),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                    style: const TextStyle(color: NeonPalette.text,
                        fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  ClipRRect(borderRadius: BorderRadius.circular(3),
                    child: Stack(children: [
                      Container(height: 3, color: NeonPalette.surfaceElevated),
                      FractionallySizedBox(widthFactor: bar,
                        child: Container(height: 3, decoration: BoxDecoration(
                          color: _kRose,
                          boxShadow: [BoxShadow(
                              color: _kRose.withValues(alpha: 0.5), blurRadius: 6)]))),
                    ])),
                ],
              )),
              const SizedBox(width: 12),
              Text(
                hasUsage ? _fmt(seconds) : '—',
                style: TextStyle(
                    color: hasUsage ? _kRose : NeonPalette.textDim,
                    fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── Game row ───────────────────────────────────────────────────────────────

  Widget _buildGameRow(GameStat g) {
    final color = _gameColor(g.name);
    final pct   = (g.winRate * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(
          shape: BoxShape.circle, color: color,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)])),
        const SizedBox(width: 10),
        SizedBox(width: 80,
          child: Text(g.name.toUpperCase(), style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1))),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
          child: Stack(children: [
            Container(height: 4, color: NeonPalette.surfaceElevated),
            FractionallySizedBox(widthFactor: g.winRate.clamp(0.0, 1.0),
              child: Container(height: 4, decoration: BoxDecoration(
                color: color,
                boxShadow: [BoxShadow(
                    color: color.withValues(alpha: 0.5), blurRadius: 5)]))),
          ]))),
        const SizedBox(width: 10),
        Text('$pct%', style: TextStyle(
            color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Text('${g.wins}W ${g.losses}L',
            style: const TextStyle(color: NeonPalette.textMuted, fontSize: 11)),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _label(String t) => Text(t, style: const TextStyle(
      color: NeonPalette.textMuted, fontSize: 10,
      fontWeight: FontWeight.w700, letterSpacing: 3));

  Widget _statRow(String label, String value, Color color) => Row(children: [
    Container(width: 3, height: 3, decoration: BoxDecoration(
      shape: BoxShape.circle, color: color,
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4)])),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(color: NeonPalette.textMuted,
        fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
    const Spacer(),
    Text(value, style: TextStyle(
        color: color, fontSize: 13, fontWeight: FontWeight.w800)),
  ]);

  Widget _timeCell(String value, String label, Color color) =>
      Expanded(child: Column(children: [
        Text(value, style: TextStyle(color: color,
            fontSize: 13, fontWeight: FontWeight.w900,
            shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 8)])),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: NeonPalette.textMuted,
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2)),
      ]));

  Widget _vDivider() => Container(width: 0.5, height: 28, color: NeonPalette.border);
  Widget _divider()  => Container(height: 0.5, color: NeonPalette.border);

  Widget _progressBar(double p) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: Stack(children: [
      Container(height: 6, color: NeonPalette.surfaceElevated),
      FractionallySizedBox(widthFactor: p, child: Container(
        height: 6, decoration: const BoxDecoration(
          color: _kRose,
          boxShadow: [BoxShadow(color: Color(0x66FF1A5C), blurRadius: 8)]))),
    ]),
  );

  Widget _bonusPill(int s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: _kAmber.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kAmber.withValues(alpha: 0.25), width: 0.5),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.bolt_rounded, size: 12, color: _kAmber),
      const SizedBox(width: 5),
      Text('${_fmt(s)} bonus used', style: const TextStyle(
          color: _kAmber, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );

  Color _gameColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('blackjack')) return NeonPalette.mint;
    if (n.contains('roulette'))  return _kRose;
    if (n.contains('mines'))     return NeonPalette.cyan;
    return NeonPalette.violet;
  }

  String _fmt(int seconds) {
    if (seconds < 60)    return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m < 60)   return s > 0 ? '${m}m ${s}s' : '${m}m';
    final h = m ~/ 60;
    final rm = m % 60;
    if (h < 24)   return rm > 0 ? '${h}h ${rm}m' : '${h}h';
    final d = h ~/ 24;
    final rh = h % 24;
    if (d < 365)  return rh > 0 ? '${d}d ${rh}h' : '${d}d';
    final y = d ~/ 365;
    final rd = d % 365;
    return rd > 0 ? '${y}y ${rd}d' : '${y}y';
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NeonCard extends StatelessWidget {
  final Widget child;
  const _NeonCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: NeonPalette.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: NeonPalette.borderBright, width: 0.5),
    ),
    child: child,
  );
}

class _AppIcon extends StatelessWidget {
  final AppInfo? info;
  final double size;
  const _AppIcon({required this.info, required this.size});

  @override
  Widget build(BuildContext context) {
    if (info?.icon != null && info!.icon!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(info!.icon!, width: size, height: size,
          fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder()),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: NeonPalette.surfaceElevated,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: NeonPalette.border, width: 0.5),
    ),
    child: const Icon(Icons.android_rounded, color: NeonPalette.textMuted, size: 20),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color  color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    canvas.drawCircle(center, radius, Paint()
      ..color = NeonPalette.surfaceElevated
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7);
    if (progress <= 0) return;
    final arc   = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(arc, -math.pi / 2, sweep, false, Paint()
      ..color = color ..style = PaintingStyle.stroke ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawArc(arc, -math.pi / 2, sweep, false, Paint()
      ..color = color ..style = PaintingStyle.stroke ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
