import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';
import '../api/api_constants.dart';

/// Must match the channel id sent by the backend and declared in AndroidManifest.xml.
const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
  'songothon_default',
  'Songothon notifications',
  description: 'Deposits, membership updates and reminders',
  importance: Importance.high,
);

/// Handles FCM setup, device-token registration with the backend and
/// showing notifications while the app is in the foreground.
class PushNotificationService {
  final ApiClient apiClient;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSub;
  bool _initialized = false;

  PushNotificationService({required this.apiClient});

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();

      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_defaultChannel);

      // FCM does not display notifications while the app is open, so show them locally.
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      _initialized = true;
    } catch (e) {
      debugPrint('[Push] Firebase initialisation failed: $e');
    }
  }

  /// Requests permission, then sends this device's FCM token to the backend.
  /// Call after the user is authenticated.
  Future<void> registerDevice() async {
    if (!_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[Push] Notification permission denied');
        return;
      }

      // The backend sends via FCM v1 registration tokens, so keep the token API.
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _sendToken(token);

      // ignore: deprecated_member_use
      _tokenRefreshSub ??= messaging.onTokenRefresh.listen(_sendToken);
    } catch (e) {
      debugPrint('[Push] Device registration failed: $e');
    }
  }

  /// Stops token sync and invalidates this device's token on logout.
  Future<void> unregisterDevice() async {
    if (!_initialized) return;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    try {
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  Future<void> _sendToken(String token) async {
    try {
      await apiClient.dio.post(ApiConstants.fcmToken, data: {'fcm_token': token});
    } catch (e) {
      debugPrint('[Push] Failed to send FCM token to backend: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannel.id,
          _defaultChannel.name,
          channelDescription: _defaultChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
