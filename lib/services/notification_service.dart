import 'dart:io';
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
      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'default_channel_id', 
        'Default Channel', 
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      print('Error initializing local notifications: $e');
    }
  }

  Future<void> _configureFCM() async {
    try {
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

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

    String? currentUserId = _auth.currentUser?.uid;

    String senderId = message.data['senderId'] ?? '';

    if (senderId == currentUserId) {
      print('Message is from the current user. Skipping notification.');
      return;
    }

    String notificationType = message.data['type'] ?? '';

    String? notificationTitle = message.notification?.title;
    String? notificationBody = message.notification?.body;

    if (notificationType == 'friend_request') {
      // Friend request notification
      String body = message.data['body'] ?? notificationBody ?? '';
      await _showLocalNotification(title: 'New Friend Request', body: body);
    } else if (notificationType == 'new_participant') {
      // Waiting Room notification
      String body = message.data['body'] ?? notificationBody ?? '';
      await _showLocalNotification(title: 'New Ride Participant', body: body);
    } else if (notificationType == 'chat_message' ||
        notificationType == 'ride_chat_message') {
      // Chat message notifications
      String senderUsername = message.data['senderUsername'] ?? 'Unknown';
      String content = message.data['content'] ?? notificationBody ?? '';
      await _showLocalNotification(title: '@$senderUsername', body: content);
    } else {
      // Handle other notification types
      String title = notificationTitle ?? 'New Notification';
      String body = notificationBody ?? '';
      await _showLocalNotification(title: title, body: body);
    }
  }

  Future<void> _showLocalNotification(
      {required String title, required String body}) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'default_channel_id', // Must match the channel ID created
        'Default Channel',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
      );
      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const NotificationDetails platformDetails = NotificationDetails(
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
    }
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    print('App opened from notification: ${message.messageId}');
    // Handle the message and navigate to desired screen
    // Implement navigation logic here
  }

  void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    // Handle notification tap and navigate if necessary
    // Implement navigation logic here
  }
}