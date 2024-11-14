import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late FirebaseMessaging _fcm;
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  late FirebaseFirestore _firestore;
  late FirebaseAuth _auth;

  Future<void> init() async {
    _fcm = FirebaseMessaging.instance;
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;

    try {
      await _requestPermissions();
      await _initializeLocalNotifications();
      await _configureFCM();
    } catch (e) {
      print('Error during notification service initialization: $e');
      // Handle initialization error appropriately
    }
  }

  Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      print('User granted permission: ${settings.authorizationStatus}');

      if (Platform.isIOS) {
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      print('Error requesting notification permissions: $e');
      // Handle permission request error
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      final InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
    } catch (e) {
      print('Error initializing local notifications: $e');
      // Handle initialization error
    }
  }

  Future<void> _configureFCM() async {
    try {
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToFirestore(token);
      } else {
        print('FCM token is null');
      }

      _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
    } catch (e) {
      print('Error configuring FCM: $e');
      // Handle FCM configuration error
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentReference userRef = _firestore.collection('users').doc(user.uid);

      try {
        await _firestore.runTransaction((transaction) async {
          DocumentSnapshot userSnapshot = await transaction.get(userRef);
          List<dynamic> tokens = userSnapshot['fcmTokens'] ?? [];

          if (!tokens.contains(token)) {
            transaction.update(userRef, {
              'fcmTokens': FieldValue.arrayUnion([token]),
            });
            print('FCM Token saved to Firestore for user ${user.uid}');
          } else {
            print('FCM Token already exists for user ${user.uid}');
          }
        });
      } catch (e) {
        print('Error saving FCM token to Firestore: $e');
        // Handle Firestore transaction error
      }
    } else {
      print('No user is currently signed in. Cannot save FCM token.');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received a message in the foreground: ${message.messageId}');
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification}');

    // Get current user ID
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Get sender ID from message data
    String senderId = message.data['senderId'] ?? '';

    // Skip if the message is from the current user
    if (senderId == currentUserId) {
      print('Message is from the current user. Skipping notification.');
      return;
    }

    // Skip showing local notification if the system has already displayed it
    if (message.notification != null) {
      print('System notification already displayed. Skipping local notification.');
      return;
    }

    String notificationType = message.data['type'] ?? '';

    if (notificationType == 'friend_request') {
      // Friend request notification
      String body = message.data['body'] ?? '';
      await _showLocalNotification(title: 'New Friend Request', body: body);
    } else if (notificationType == 'new_participant') {
      // Waiting Room notification
      String body = message.data['body'] ?? '';
      await _showLocalNotification(title: 'New Ride Participant', body: body);
    } else if (notificationType == 'chat_message' || notificationType == 'ride_chat_message') {
      // Chat message notifications
      String senderUsername = message.data['senderUsername'] ?? 'Unknown';
      String content = message.data['content'] ?? '';
      await _showLocalNotification(title: '@$senderUsername', body: content);
    }
  }

  Future<void> _showLocalNotification({required String title, required String body}) async {
    try {
      AndroidNotificationDetails androidDetails = const AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      DarwinNotificationDetails iOSDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        title.hashCode ^ body.hashCode,
        title,
        body,
        platformDetails,
        payload: 'Default_Sound',
      );
    } catch (e) {
      print('Error showing local notification: $e');
      // Handle notification display error
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('Handling a background message: ${message.messageId}');
    // Implement any specific background message handling here
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap here
    print('Notification tapped: ${response.payload}');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  // Implement any specific background message handling here
}