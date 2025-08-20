import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized in background isolate
  await Firebase.initializeApp();
  debugPrint('[PushService] Background message: ${message.messageId}');
}

class PushService {
  static bool _initialized = false;

  static Future<void> initializeAndRegister() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // Firebase init is idempotent; safe to call if already initialized elsewhere
      await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;

      // Background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // iOS permission request; no-op on Android
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Get current token
      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      // Listen for refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await _registerToken(newToken);
      });

      // Re-register on auth state changes
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session != null) {
          final latest = await FirebaseMessaging.instance.getToken();
          if (latest != null) {
            await _registerToken(latest);
          }
        } else {
          final current = await FirebaseMessaging.instance.getToken();
          if (current != null) {
            await Supabase.instance.client
                .rpc('unregister_push_token', params: {'p_token': current});
          }
        }
      });

      // Optional foreground handler (keep minimal; app-specific UI can be added later)
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[PushService] Foreground message: ${message.notification?.title} - ${message.notification?.body}');
      });
    } catch (e) {
      debugPrint('[PushService] Initialization error: $e');
    }
  }

  static Future<void> unregisterCurrentToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await Supabase.instance.client.rpc('unregister_push_token', params: {
          'p_token': token,
        });
      }
    } catch (e) {
      debugPrint('[PushService] Unregister error: $e');
    }
  }

  static Future<void> _registerToken(String token) async {
    try {
      final platform = kIsWeb
          ? 'web'
          : Platform.isAndroid
              ? 'android'
              : Platform.isIOS
                  ? 'ios'
                  : 'unknown';
      await Supabase.instance.client.rpc('register_push_token', params: {
        'p_token': token,
        'p_platform': platform,
      });
      debugPrint('[PushService] Registered push token for platform=$platform');
    } catch (e) {
      debugPrint('[PushService] Register token error: $e');
    }
  }
}


