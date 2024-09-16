import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_functions/cloud_functions.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> init() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _initializeLocalNotifications();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    String? token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      _showLocalNotification(message.notification!);
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('Handling a background message: ${message.messageId}');
    // Handle the background message, e.g., navigate to a specific screen
  }

  Future<void> _showLocalNotification(RemoteNotification notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'your_channel_id',
      'your_channel_name',
      importance: Importance.max,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      notification.title,
      notification.body,
      platformChannelSpecifics,
    );
  }

  Future<void> sendFriendRequestNotification(String toUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Get the current user's username
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    String username = userDoc['username'] ?? 'A user';

    try {
      await _functions.httpsCallable('sendFriendRequestNotification').call({
        'toUserId': toUserId,
        'fromUserId': currentUser.uid,
        'fromUsername': username,
      });
    } catch (e) {
      print('Error sending friend request notification: $e');
      throw e; // Rethrow the error so it can be caught in the _addFriend method
    }
  }

  Future<void> sendNewParticipantNotification(String toUserId, String newUsername, String rideId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      await _functions.httpsCallable('sendNewParticipantNotification').call({
        'toUserId': toUserId,
        'newUsername': newUsername,
        'rideId': rideId,
      });
    } catch (e) {
      print('Error sending new participant notification: $e');
    }
  }
}