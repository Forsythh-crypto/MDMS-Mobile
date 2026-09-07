import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../constants.dart';

// Background Message Handler - Needs to be a top level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}

class FirebaseApi {
  // create an instance of Firebase Messaging
  final _firebaseMessaging = FirebaseMessaging.instance;
  // create local notifications instance
  final _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    // request permission from user (will prompt on iOS, required for newer Android)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Specifically request for Android 13+ using Local Notifications plugin
    final androidPlatform = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlatform != null) {
      await androidPlatform.requestNotificationsPermission();
    }

    // fetch the FCM token for this device
    String? fCMToken;
    try {
      fCMToken = await _firebaseMessaging.getToken();
      debugPrint("Firebase FCM Token: $fCMToken");
    } catch (e) {
      debugPrint("Could not fetch FCM token: $e");
      // This is expected on iOS Simulators without APNS setup.
    }
    
    // Save token to backend if the user is already logged in
    await saveTokenToBackend(fCMToken);

    // Watch for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      saveTokenToBackend(newToken);
    });

    // initialize further settings for foreground/background
    initPushNotifications();
    initLocalNotifications();
  }

  // Stream to broadcast tapped messages
  static final StreamController<RemoteMessage> onMessageTapped = StreamController.broadcast();

  // Handle message when received
  void handleMessage(RemoteMessage? message) {
    // If the message is null, do nothing
    if (message == null) return;
    
    debugPrint("Opened notification: ${message.notification?.title}");
    
    // Broadcast the message so any listening screens (like NotificationsScreen) can act on it
    onMessageTapped.add(message);
  }

  // Initialize background settings
  Future initPushNotifications() async {
    // handle notification if the app was terminated and now opened
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);

    // attach event listeners for when a notification opens the app 
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);

    // handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle incoming messages while the app is in the Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          )
        ),
        payload: jsonEncode(message.data),
      );
    });
  }

  Future initLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final message = RemoteMessage(data: jsonDecode(response.payload!));
          handleMessage(message);
        }
      },
    );

    // Create Android channel so foreground notifications pop up
    final platform = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await platform?.createNotificationChannel(const AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
    ));
  }

  // Sends the token to the Laravel Backend
  static Future<void> saveTokenToBackend(String? fcmToken) async {
    if (fcmToken == null) return;
    final prefs = await SharedPreferences.getInstance();
    final apiToken = prefs.getString('api_token');
    
    if (apiToken == null || apiToken.isEmpty) return; // User is not logged in

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/settings/fcm-token'), // Your Laravel Route to save token
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $apiToken',
        },
        body: {
          'fcm_token': fcmToken,
        },
      );
      debugPrint("FCM Sync Status: ${response.statusCode}");
      debugPrint("FCM Sync Response: ${response.body}");
    } catch (e) {
      debugPrint("Failed to send FCM token to backend: $e");
    }
  }

  // Helper to trigger a manual sync
  static Future<void> syncToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await saveTokenToBackend(token);
    } catch (e) {
      debugPrint("Sync Token failed: $e");
    }
  }
}
