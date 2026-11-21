import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging setup.
///
/// Push is optional: until you add `android/app/google-services.json`
/// (run `flutterfire configure`), Firebase fails to initialise and the app
/// silently falls back to in-app notifications, refreshed from the API.
class PushService {
  bool _ready = false;
  bool get isReady => _ready;

  /// Called with (title, body) when a push arrives while the app is open.
  void Function(String title, String body)? onForegroundMessage;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) onForegroundMessage?.call(n.title ?? 'RUPP Eat', n.body ?? '');
      });
      _ready = true;
    } catch (e) {
      debugPrint('Push notifications disabled (Firebase not configured): $e');
    }
  }

  Future<String?> token() async {
    if (!_ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}
