import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    FirebaseMessaging.onMessage.listen((_) {
      // Intentionally no in-app popup.
      // OS-level notifications are handled when app is background/terminated.
    });

    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      // Reserved for deep-link handling if needed.
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await registerCurrentToken(tokenOverride: token);
    });
  }

  Future<void> registerCurrentToken({String? tokenOverride}) async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    final token = tokenOverride ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    await client.rpc('register_push_token', params: {
      'p_token': token,
      'p_platform': _platformLabel(),
    });
  }

  Future<void> unregisterCurrentToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await Supabase.instance.client.rpc('unregister_push_token', params: {
      'p_token': token,
    });
  }

  String _platformLabel() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }
}

