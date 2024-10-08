import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  late FirebaseMessaging _fcm;
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  late FirebaseFirestore _firestore;
  late FirebaseAuth _auth;

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-west2');

  Future<void> init() async {
    _fcm = FirebaseMessaging.instance;
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;

    await _requestPermissions();
    await _initializeLocalNotifications();
    await _configureFCM();
    await _saveInitialToken();
  }

  Future<void> _requestPermissions() async {
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
  }

  Future<void> _initializeLocalNotifications() async {
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
  }

  Future<void> _configureFCM() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
  }

  Future<void> _saveInitialToken() async {
    String? token = await _fcm.getToken();
    if (token != null) {
      print('Initial FCM Token: $token');
      await _saveTokenToFirestore(token);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
      print('FCM Token saved to Firestore for user ${user.uid}');
    }
  }

   Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received a message in the foreground: ${message.messageId}');
    print('Message data: ${message.data}');

    String notificationType = message.data['type'] ?? '';

    if (notificationType == 'friend_request') {
      // Friend request notification
      await _showLocalNotification(RemoteNotification(
        title: 'New Friend Request',
        body: message.notification?.body ?? '',
      ));
    } else if (notificationType == 'new_participant') {
      // Waiting Room notification
      await _showLocalNotification(RemoteNotification(
        title: 'New Ride Participant',
        body: message.notification?.body ?? '',
      ));
    } else if (notificationType == 'chat_message' || notificationType == 'ride_chat_message') {
      // Chat message notifications
      await _showLocalNotification(RemoteNotification(
        title: message.notification?.title ?? '',
        body: message.notification?.body ?? '',
      ));
    } else if (message.notification != null) {
      await _showLocalNotification(message.notification!);
    }
  }

  Future<void> _showLocalNotification(RemoteNotification notification) async {
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
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: 'Default_Sound',
    );
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