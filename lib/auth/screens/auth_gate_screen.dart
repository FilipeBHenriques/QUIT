import 'dart:math' as math;

import 'package:flutter/material.dart' as flutter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../core/local_profile_store.dart';

class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen>
    with flutter.TickerProviderStateMixin {
  late final flutter.AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = flutter.AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _continueWithoutAccount() async {
    await ref.read(authControllerProvider.notifier).signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guest_mode', true);
    await LocalProfileStore(prefs).ensureActiveMode(guestEnabled: true);
    if (!mounted) return;
    context.go('/');
  }

  @override
  flutter.Widget build(flutter.BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth.loading) {
      return const flutter.Scaffold(
        body: flutter.Center(child: flutter.CircularProgressIndicator()),
      );
    }

    return flutter.Scaffold(
      body: flutter.Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const flutter.BoxDecoration(
          gradient: flutter.LinearGradient(
            begin: flutter.Alignment.topCenter,
            end: flutter.Alignment.bottomCenter,
            colors: [
              flutter.Color(0xFF04050C),
              flutter.Color(0xFF020408),
              flutter.Color(0xFF030408),
            ],
          ),
        ),
        child: flutter.Stack(
          children: [
            flutter.CustomPaint(
              painter: _GridPainter(),
              size: flutter.Size.infinite,
            ),
            flutter.SafeArea(
              child: flutter.Center(
                child: flutter.Padding(
                  padding: const flutter.EdgeInsets.all(24),
                  child: flutter.Column(
                    mainAxisSize: flutter.MainAxisSize.min,
                    crossAxisAlignment: flutter.CrossAxisAlignment.center,
                    children: [
                      flutter.AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, _) {
                          const letters = ['Q', 'U', 'I', 'T'];
                          const white = flutter.Color(0xFFFFFFFF);
                          return flutter.Row(
                            mainAxisSize: flutter.MainAxisSize.min,
                            children: List.generate(letters.length, (i) {
                              final g = (math.sin(
                                            _waveController.value *
                                                    2 *
                                                    math.pi -
                                                i * math.pi / 2,
                                          ) +
                                          1) /
                                      2;
                              return flutter.Container(
                                margin: const flutter.EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                width: 68,
                                height: 74,
                                decoration: flutter.BoxDecoration(
                                  color: const flutter.Color(0xFF080A12),
                                  borderRadius: flutter.BorderRadius.circular(
                                    10,
                                  ),
                                  border: flutter.Border.all(
                                    color: white.withValues(
                                      alpha: 0.10 + g * 0.55,
                                    ),
                                    width: 0.5,
                                  ),
                                  boxShadow: [
                                    flutter.BoxShadow(
                                      color: white.withValues(alpha: g * 0.18),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                alignment: flutter.Alignment.center,
                                child: flutter.Text(
                                  letters[i],
                                  style: flutter.TextStyle(
                                    fontSize: 36,
                                    fontWeight: flutter.FontWeight.w800,
                                    color: flutter.Color.lerp(
                                      const flutter.Color(0xFF3A4055),
                                      const flutter.Color(0xFFFFFFFF),
                                      g,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const flutter.SizedBox(height: 20),
                      const flutter.Text(
                        'FOCUSED LIVING',
                        style: flutter.TextStyle(
                          color: flutter.Color(0xFF6E7488),
                          fontSize: 10,
                          fontWeight: flutter.FontWeight.w700,
                          letterSpacing: 6,
                        ),
                      ),
                      const flutter.SizedBox(height: 28),
                      flutter.SizedBox(
                        width: double.infinity,
                        child: flutter.ElevatedButton(
                          onPressed: () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle(),
                          style: flutter.ElevatedButton.styleFrom(
                            backgroundColor: const flutter.Color(0xFFFFFFFF),
                            foregroundColor: const flutter.Color(0xFF202124),
                            elevation: 0,
                            shadowColor: flutter.Colors.transparent,
                            shape: flutter.RoundedRectangleBorder(
                              borderRadius: flutter.BorderRadius.circular(999),
                              side: const flutter.BorderSide(
                                color: flutter.Color(0xFFDADCE0),
                                width: 1,
                              ),
                            ),
                            padding: const flutter.EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          child: const flutter.Row(
                            mainAxisAlignment: flutter.MainAxisAlignment.center,
                            children: [
                              flutter.Image(
                                image: flutter.AssetImage(
                                  'assets/icon/google_g_logo.png',
                                ),
                                width: 18,
                                height: 18,
                              ),
                              flutter.SizedBox(width: 12),
                              flutter.Text(
                                'Continue with Google',
                                style: flutter.TextStyle(
                                  fontSize: 15,
                                  fontWeight: flutter.FontWeight.w600,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const flutter.SizedBox(height: 10),
                      flutter.SizedBox(
                        width: double.infinity,
                        child: flutter.OutlinedButton(
                          onPressed: _continueWithoutAccount,
                          style: flutter.OutlinedButton.styleFrom(
                            foregroundColor: const flutter.Color(0xFFE9EDFA),
                            side: const flutter.BorderSide(
                              color: flutter.Color(0x55FFFFFF),
                            ),
                            padding: const flutter.EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                          child: const flutter.Text('Guest Login'),
                        ),
                      ),
                      if (auth.error != null) ...[
                        const flutter.SizedBox(height: 12),
                        flutter.Text(
                          auth.error!,
                          style: const flutter.TextStyle(
                            color: flutter.Colors.redAccent,
                          ),
                          textAlign: flutter.TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends flutter.CustomPainter {
  @override
  void paint(flutter.Canvas canvas, flutter.Size size) {
    final paint = flutter.Paint()
      ..color = const flutter.Color(0xFF14161E).withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(flutter.Offset(x, 0), flutter.Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(flutter.Offset(0, y), flutter.Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant flutter.CustomPainter oldDelegate) => false;
}
