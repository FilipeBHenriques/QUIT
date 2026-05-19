import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../models/profile.dart';
import 'cloud_state_service.dart';

class AuthService {
  AuthService(this._supabase, this._googleSignIn);

  final SupabaseClient _supabase;
  final GoogleSignIn _googleSignIn;

  Session? get session => _supabase.auth.currentSession;

  Future<void> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google sign in canceled');
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;

    if (idToken == null || accessToken == null) {
      throw Exception('Missing Google tokens');
    }

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    await bootstrapProfile();
    await CloudStateService(_supabase).hydrateLocalCacheFromCloud();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }

  Future<Profile?> getMyProfile() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await _supabase
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(row);
  }

  Future<Profile> bootstrapProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final meta = user.userMetadata ?? const <String, dynamic>{};
    final username = (meta['full_name'] ?? meta['name'] ?? user.email ?? 'User') as String;
    final avatar = meta['avatar_url'] as String?;

    final row = await _supabase.rpc('bootstrap_profile', params: {
      'p_username': username,
      'p_avatar_url': avatar,
    });

    return Profile.fromJson((row as Map<String, dynamic>));
  }

  Future<void> updateLastSeen() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    await _supabase.from('profiles').update({
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  Future<Profile> updateUsername(String username) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('No authenticated user');
    final clean = username.trim();
    if (clean.isEmpty) throw Exception('Username cannot be empty');

    final row = await _supabase
        .from('profiles')
        .update({'username': clean, 'last_seen_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', uid)
        .select()
        .single();

    return Profile.fromJson((row as Map).cast<String, dynamic>());
  }

  Future<Profile> updateAvatar(Uint8List bytes) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('No authenticated user');

    final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    final avatarUrl = _supabase.storage.from('avatars').getPublicUrl(path);

    final row = await _supabase
        .from('profiles')
        .update({
          'avatar_url': avatarUrl,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', uid)
        .select()
        .single();

    return Profile.fromJson((row as Map).cast<String, dynamic>());
  }

  Future<void> resetMyAccountData() async {
    await _supabase.rpc('reset_my_account_data');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('remaining_seconds', 0);
    await prefs.setInt('daily_limit_seconds', 0);
    await prefs.setInt('used_today_seconds', 0);
    await prefs.setInt('gambling_lost_today_seconds', 0);
    await prefs.remove('timer_last_reset');
    await prefs.remove('daily_time_ran_out_timestamp');
    await prefs.remove('last_bonus_time');
    await prefs.remove('timer_first_choice_made');

    await CloudStateService(_supabase).hydrateLocalCacheFromCloud();
  }
}
