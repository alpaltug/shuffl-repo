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

    if (message.notification != null) {
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

   Future<void> sendFriendRequestNotification(String toUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('Current user is null');
      throw Exception('User not authenticated');
    }

    try {
      String username = await _getUsernameById(currentUser.uid);
      
      print('Sending friend request notification:');
      print('From: ${currentUser.uid} ($username)');
      print('To: $toUserId');

      // Check if the recipient exists and has FCM tokens
      DocumentSnapshot recipientDoc = await _firestore.collection('users').doc(toUserId).get();
      if (!recipientDoc.exists) {
        throw Exception('Recipient user does not exist');
      }
      List<String> recipientTokens = List<String>.from(recipientDoc['fcmTokens'] ?? []);
      if (recipientTokens.isEmpty) {
        throw Exception('Recipient has no FCM tokens');
      }

      HttpsCallable callable = _functions.httpsCallable('sendFriendRequestNotification');
      final result = await callable.call({
        'toUserId': toUserId,
        'fromUserId': currentUser.uid,
        'fromUsername': username,
      });

      print('Cloud Function result: ${result.data}');
      if (result.data['success'] == false) {
        throw Exception('Failed to send notification: ${result.data['error']}');
      }
    } catch (e) {
      print('Error in sendFriendRequestNotification: $e');
      if (e is FirebaseFunctionsException) {
        print('Firebase Functions Error Code: ${e.code}');
        print('Firebase Functions Error Details: ${e.details}');
      }
      rethrow;
    }
  }

  Future<String> _getUsernameById(String userId) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    return userDoc['username'] ?? 'Unknown User';
  }

  Future<void> sendNewParticipantNotification(String toUserId, String newUsername, String rideId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      HttpsCallable callable = _functions.httpsCallable('sendNewParticipantNotification');
      final result = await callable.call({
        'toUserId': toUserId,
        'newUsername': newUsername,
        'rideId': rideId,
      });
      print('New participant notification sent: ${result.data}');
    } catch (e) {
      print('Error sending new participant notification: $e');
      if (e is FirebaseFunctionsException) {
        print('Firebase Functions Error Code: ${e.code}');
        print('Firebase Functions Error Details: ${e.details}');
      }
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  // Implement any specific background message handling here
}