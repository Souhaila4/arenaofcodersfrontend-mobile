import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:arena/core/services/api_service.dart';

/// Handles FCM push notifications (foreground + background)
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;
  PushNotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _api = ApiService();
  bool _initialized = false;

  /// Initialize the push notification service
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('🔔 Push notification permission: ${settings.authorizationStatus}');

    // Setup local notifications (for foreground notifications)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(settings: initSettings);

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'hackathon_notifications',
      'Hackathon Notifications',
      description: 'Notifications for new hackathons and updates',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Get FCM token and send to backend
    final token = await _messaging.getToken();
    if (token != null) {
      print('🔔 FCM Token: $token');
      await _registerToken(token);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      print('🔔 FCM Token refreshed: $newToken');
      _registerToken(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Handle background/terminated message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🔔 Message opened: ${message.notification?.title}');
      // Could navigate to a specific screen here
    });
  }

  /// Register the FCM token with the backend
  Future<void> _registerToken(String token) async {
    try {
      await _api.registerFcmToken(token);
      print('🔔 FCM token registered with backend');
    } catch (e) {
      print('🔔 Failed to register FCM token: $e');
    }
  }

  /// Show a local notification when a message arrives while app is in foreground
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'hackathon_notifications',
          'Hackathon Notifications',
          channelDescription: 'Notifications for new hackathons and updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
