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

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor( app: Firebase.app(), region: 'us-west2');

  Future<void> init() async {
    _fcm = FirebaseMessaging.instance;
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;

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
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
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
    print('Received a message in the foreground: ${message.messageId}');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      _showLocalNotification(message.notification!);
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('Handling a background message: ${message.messageId}');
  }

  Future<void> _showLocalNotification(RemoteNotification notification) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'your_channel_id', // Replace with channel ID FOR ANDROID
      'your_channel_name', // Replace with channel name FOR ANDROID
      importance: Importance.max,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      notification.title,
      notification.body,
      platformDetails,
    );
  }

  Future<void> sendFriendRequestNotification(String toUserId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('Current user is null');
      throw Exception('User not authenticated');
    }

    try {
      print('Current user UID: ${currentUser.uid}');
      print('Current user email: ${currentUser.email}');
      
      String? token = await currentUser.getIdToken(true);
      print('Updated ID token: ${token?.substring(0, 10)}...');

      String username = await _getUsernameById(currentUser.uid);
      print('Username: $username');

      print('Calling Cloud Function with parameters:');
      print('toUserId: $toUserId');
      print('fromUserId: ${currentUser.uid}');
      print('fromUsername: $username');

      HttpsCallable callable = _functions.httpsCallable('sendFriendRequestNotification');
      final result = await callable.call({
        'toUserId': toUserId,
        'fromUserId': currentUser.uid,
        'fromUsername': username,
      });

      print('Cloud Function result: $result');
    } catch (e) {
      print('Error in sendFriendRequestNotification: $e');
      if (e is FirebaseFunctionsException) {
        print('Firebase Functions Error Code: ${e.code}');
        print('Firebase Functions Error Details: ${e.details}');
      }
      throw e;
    }
  }

  Future<String> _getUsernameById(String userId) async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
    return userDoc['username'] ?? 'Unknown User';
  }

  Future<void> sendNewParticipantNotification(
      String toUserId, String newUsername, String rideId) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      HttpsCallable callable = _functions.httpsCallable('sendNewParticipantNotification');
      await callable.call({
        'toUserId': toUserId,
        'newUsername': newUsername,
        'rideId': rideId,
      });
    } catch (e) {
      print('Error sending new participant notification: $e');
    }
  }
}