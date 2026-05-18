import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_env.dart';
import '../../social/models/profile.dart';
import '../../social/services/auth_service.dart';

class AuthState {
  const AuthState({
    required this.loading,
    this.session,
    this.profile,
    this.error,
  });

  final bool loading;
  final Session? session;
  final Profile? profile;
  final String? error;

  bool get isAuthenticated => session != null;

  AuthState copyWith({
    bool? loading,
    Session? session,
    Profile? profile,
    String? error,
  }) {
    return AuthState(
      loading: loading ?? this.loading,
      session: session ?? this.session,
      profile: profile ?? this.profile,
      error: error,
    );
  }

  static const initial = AuthState(loading: true);
}

final authServiceProvider = Provider<AuthService>((ref) {
  final serverClientId = AppEnv.googleServerClientId.trim();
  return AuthService(
    Supabase.instance.client,
    GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    ),
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._service) : super(AuthState.initial) {
    _init();
  }

  final AuthService _service;

  Future<void> _init() async {
    try {
      final session = _service.session;
      final profile = await _service.getMyProfile();
      state = AuthState(loading: false, session: session, profile: profile);
    } catch (e) {
      state = AuthState(loading: false, error: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _service.signInWithGoogle();
      final session = _service.session;
      final profile = await _service.getMyProfile();
      state = AuthState(loading: false, session: session, profile: profile);
    } catch (e) {
      state = AuthState(loading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = const AuthState(loading: false);
  }

  Future<void> refreshProfile() async {
    final profile = await _service.getMyProfile();
    state = state.copyWith(profile: profile);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});
