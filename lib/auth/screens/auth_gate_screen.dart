import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
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
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * math.pi * 2;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + math.sin(t) * 0.2, -1),
                end: Alignment(1, 1 - math.cos(t) * 0.2),
                colors: const [
                  Color(0xFF04060D),
                  Color(0xFF0A1120),
                  Color(0xFF170A14),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -80 + math.sin(t) * 30,
                  left: -40,
                  child: _glowOrb(const Color(0x66FF1A5C), 220),
                ),
                Positioned(
                  bottom: -120 + math.cos(t * 1.3) * 35,
                  right: -60,
                  child: _glowOrb(const Color(0x5530D5FF), 260),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'QUIT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Beat compulsive loops.\nControl your time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFB8C1D6),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => ref
                                .read(authControllerProvider.notifier)
                                .signInWithGoogle(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF1A5C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Continue with Google'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _continueWithoutAccount,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE6EBFF),
                              side: const BorderSide(
                                color: Color(0x55FFFFFF),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('No account (local only)'),
                          ),
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            auth.error!,
                            style: const TextStyle(color: Colors.redAccent),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _glowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, const Color(0x00000000)],
        ),
      ),
    );
  }
}
