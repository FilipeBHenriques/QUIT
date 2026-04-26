import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:quit/game_result.dart';
import 'package:quit/services/stats_service.dart';
import 'package:quit/theme/neon_palette.dart';
import 'package:quit/widgets/neon_button.dart';

class GameResultScreen extends StatefulWidget {
  final GameResult result;
  final String packageName;
  final String appName;

  const GameResultScreen({
    super.key,
    required this.result,
    required this.packageName,
    required this.appName,
  });

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen>
    with TickerProviderStateMixin {
  static const navigationChannel = MethodChannel('com.quit.app/navigation');
  static const String _retryAvailableKey = 'retry_ad_available';

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _scaleController;
  late AnimationController _numberController;
  late Animation<double> _scaleAnimation;
  Animation<int>? _numberAnimation;

  // ── Timer state ─────────────────────────────────────────────────────────────
  int initialTime = 0;
  int finalTime   = 0;
  bool hasTime    = true;
  bool _isLoaded  = false;

  // ── Rewarded ad ─────────────────────────────────────────────────────────────
  static const String _rewardedAdUnitId =
      'ca-app-pub-5573070067536747/8645861520';

  RewardedAd? _rewardedAd;
  bool _adLoaded    = false;
  bool _adUsed      = false; // true once button tapped — prevents double-tap
  bool _earnedRetry = false; // true when user finishes the full ad
  bool _retryAvailable = false;

  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTimeData();
    // Only load an ad for losses, and only if not already used in this session
    if (!widget.result.won) _loadRewardedAd();
  }

  void _initializeAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _numberController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _scaleController.forward();
  }

  Future<void> _loadTimeData() async {
    final prefs = await SharedPreferences.getInstance();
    // On a retry game, the native service may have decremented remaining_seconds
    // while the user was playing. Use the guaranteed bet amount as the floor so
    // the result reflects the bet that was actually staked, not the countdown.
    final retryGuaranteed = prefs.getInt('retry_guaranteed_seconds') ?? 0;
    final rawRemaining    = prefs.getInt('remaining_seconds') ?? 0;
    final currentRemaining = math.max(rawRemaining, retryGuaranteed);
    if (retryGuaranteed > 0) await prefs.remove('retry_guaranteed_seconds');

    _retryAvailable = prefs.getBool(_retryAvailableKey) ?? false;
    initialTime = currentRemaining;

    final newRemaining = math.max(0, currentRemaining + widget.result.timeChange);
    finalTime = newRemaining;
    hasTime   = finalTime > 0;

    await prefs.setInt('remaining_seconds', finalTime);
    // Track gambling losses separately so setDailyLimit can compute consumed
    // time correctly (real usage + gambling losses) without relying on
    // used_today_seconds, which is owned by the native monitoring service.
    if (!widget.result.won) {
      final lost = prefs.getInt('gambling_lost_today_seconds') ?? 0;
      await prefs.setInt('gambling_lost_today_seconds', lost + widget.result.betAmount);
    }

    _numberAnimation = IntTween(begin: initialTime, end: finalTime).animate(
      CurvedAnimation(parent: _numberController, curve: Curves.easeOutCubic),
    );

    await StatsService.recordSession(GameSession(
      gameName: widget.result.gameName,
      won: widget.result.won,
      timeBetSeconds: widget.result.betAmount,
      timePayoutSeconds: widget.result.won
          ? widget.result.betAmount + math.max(0, widget.result.timeChange)
          : 0,
      timeResultSeconds: widget.result.timeChange,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      appPackage: widget.packageName,
      appName: widget.appName,
    ));

    setState(() => _isLoaded = true);
    _numberController.forward();
  }

  // ── Ad ─────────────────────────────────────────────────────────────────────

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          if (mounted) setState(() => _adLoaded = true);
        },
        onAdFailedToLoad: (_) {}, // silently fail — button stays in loading state
      ),
    );
  }

  Future<void> _watchAdForRetry() async {
    if (_rewardedAd == null || _adUsed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_retryAvailableKey, false);
    setState(() {
      _adUsed = true;
      _retryAvailable = false;
    }); // immediately hide to prevent double-tap

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _rewardedAd = null;
        if (!_earnedRetry || !mounted) return;

        // Pass the exact bet amount as a URL param — FirstTimeGambleScreen
        // writes it to remaining_seconds right before the game loads, after
        // all async setup (timer reload, grantBonus, etc.) is done.
        final betBack = widget.result.betAmount;
        final pkg = Uri.encodeComponent(widget.packageName);
        final app = Uri.encodeComponent(widget.appName);
        context.pushReplacement(
          '/first_time_gamble?packageName=$pkg&appName=$app&retryBet=$betBack',
        );
      },
      // No reload on failure — one chance per loss, no second ad video
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewardedAd = null;
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (_, _) => _earnedRetry = true,
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs    = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _continue() async {
    if (hasTime) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastReset = prefs.getInt('timer_last_reset') ?? 0;
        if (lastReset == 0) {
          await prefs.setInt(
            'timer_last_reset',
            DateTime.now().millisecondsSinceEpoch,
          );
        }
        await prefs.setBool('timer_first_choice_made', true);
        await navigationChannel.invokeMethod('launchApp', {
          'packageName': widget.packageName,
        });
      } catch (_) {
        await navigationChannel.invokeMethod('goHome');
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastReset = prefs.getInt('timer_last_reset') ?? 0;
        if (lastReset == 0) {
          await prefs.setInt(
            'timer_last_reset',
            DateTime.now().millisecondsSinceEpoch,
          );
          await prefs.setBool('timer_first_choice_made', true);
        }
        await navigationChannel.invokeMethod('goHome');
      } catch (_) {
        await navigationChannel.invokeMethod('goHome');
      }
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _scaleController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWin        = widget.result.won;
    final primaryColor = isWin ? NeonPalette.mint : NeonPalette.rose;
    final headline     = isWin ? 'YOU WON' : 'YOU LOST';
    final subhead      = isWin
        ? 'Nice play. Net time added after your stake.'
        : 'Rough hand. Your stake was deducted.';

    // Show immediately on any loss — button is always in the tree, just
    // disabled (spinner) until the ad finishes loading.
    final showAdButton = !isWin && !_adUsed && _retryAvailable;

    return Scaffold(
      backgroundColor: NeonPalette.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ── Close ────────────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () async =>
                        navigationChannel.invokeMethod('goHome'),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: NeonPalette.surfaceSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: NeonPalette.border, width: 0.5),
                      ),
                      child: const Icon(Icons.close,
                          color: NeonPalette.textMuted, size: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Result icon ───────────────────────────────────────────────
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: 0.08),
                    border: Border.all(
                        color: primaryColor.withValues(alpha: 0.35), width: 0.5),
                    boxShadow: [
                      BoxShadow(color: primaryColor.withValues(alpha: 0.22),
                          blurRadius: 28),
                      BoxShadow(color: primaryColor.withValues(alpha: 0.08),
                          blurRadius: 60, spreadRadius: 8),
                    ],
                  ),
                  child: Icon(
                    isWin ? Icons.check_rounded : Icons.close_rounded,
                    color: primaryColor, size: 32,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Headline ──────────────────────────────────────────────────
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Text(headline,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      shadows: [Shadow(
                          color: primaryColor.withValues(alpha: 0.7),
                          blurRadius: 30)],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(subhead,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: NeonPalette.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w400),
                ),

                // ── Watch Ad button — right here, above the cards ─────────────
                if (showAdButton) ...[
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _adLoaded ? _watchAdForRetry : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFAB00).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFFAB00).withValues(alpha: 0.35),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_adLoaded)
                            const Icon(Icons.play_circle_outline_rounded,
                                color: Color(0xFFFFAB00), size: 17)
                          else
                            const SizedBox(
                              width: 15, height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Color(0xFFFFAB00)),
                            ),
                          const SizedBox(width: 9),
                          const Text('WATCH AD · 1 MORE TRY',
                            style: TextStyle(
                              color: Color(0xFFFFAB00),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // ── Time lost/gained card ─────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 28, horizontal: 24),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: primaryColor.withValues(alpha: 0.22), width: 0.5),
                    boxShadow: [BoxShadow(
                        color: primaryColor.withValues(alpha: 0.12),
                        blurRadius: 24)],
                  ),
                  child: Column(children: [
                    Text(isWin ? 'NET TIME GAINED' : 'TIME PUT ON THE LINE',
                      style: const TextStyle(
                        color: NeonPalette.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(widget.result.timeChangeFormattedMinutes,
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 62,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        shadows: [Shadow(
                            color: primaryColor.withValues(alpha: 0.65),
                            blurRadius: 24)],
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 16),

                // ── Time remaining card ───────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: NeonPalette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NeonPalette.border, width: 0.5),
                  ),
                  child: Column(children: [
                    const Text('TIME REMAINING',
                      style: TextStyle(
                        color: NeonPalette.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _isLoaded && _numberAnimation != null
                        ? AnimatedBuilder(
                            animation: _numberAnimation!,
                            builder: (context, _) => Text(
                              _formatTime(_numberAnimation!.value),
                              style: TextStyle(
                                color: hasTime
                                    ? NeonPalette.text
                                    : NeonPalette.rose,
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          )
                        : const SizedBox(
                            height: 42,
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: NeonPalette.textMuted,
                                  strokeWidth: 1.5),
                            ),
                          ),
                  ]),
                ),

                const SizedBox(height: 28),

                // ── Primary action ────────────────────────────────────────────
                NeonButton(
                  onPressed: _continue,
                  color: NeonPalette.surfaceSoft,
                  borderColor: const Color(0xFF2A2E3F),
                  glowColor: Colors.white,
                  textColor: Colors.white,
                  glowOpacity: hasTime ? 0.10 : 0.0,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  borderRadius: 14,
                  fontSize: 13,
                  letterSpacing: 2.0,
                  text: hasTime ? 'CONTINUE TO APP' : 'GO HOME',
                ),

                if (!hasTime) ...[
                  const SizedBox(height: 14),
                  const Text('No time remaining. Try again tomorrow.',
                    style: TextStyle(
                        color: NeonPalette.textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
