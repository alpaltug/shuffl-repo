// import 'dart:io';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:cloud_functions/cloud_functions.dart';

// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();

//   late FirebaseMessaging _fcm;
//   late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
//   late FirebaseFirestore _firestore;
//   late FirebaseAuth _auth;

//   Future<void> init() async {
//     _fcm = FirebaseMessaging.instance;
//     _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
//     _firestore = FirebaseFirestore.instance;
//     _auth = FirebaseAuth.instance;

//     await _requestPermissions();
//     await _initializeLocalNotifications();
//     await _configureFCM();
//   }

//   Future<void> _requestPermissions() async {
//     NotificationSettings settings = await _fcm.requestPermission(
//       alert: true,
//       badge: true,
//       sound: true,
//       provisional: false,
//     );
//     print('User granted permission: ${settings.authorizationStatus}');

//     if (Platform.isIOS) {
//       await _fcm.setForegroundNotificationPresentationOptions(
//         alert: true,
//         badge: true,
//         sound: true,
//       );
//     }
//   }

//   Future<void> _initializeLocalNotifications() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//     final DarwinInitializationSettings initializationSettingsIOS =
//         DarwinInitializationSettings(
//       requestAlertPermission: false,
//       requestBadgePermission: false,
//       requestSoundPermission: false,
//     );
//     final InitializationSettings initializationSettings = InitializationSettings(
//       android: initializationSettingsAndroid,
//       iOS: initializationSettingsIOS,
//     );

//     await _flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: _onNotificationTap,
//     );
//   }

//   Future<void> _configureFCM() async {
//     FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
//     FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
//     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

//     String? token = await _fcm.getToken();
//     if (token != null) {
//       await _saveTokenToFirestore(token);
//     }
//     _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
//   }

//   Future<void> _saveTokenToFirestore(String token) async {
//     User? user = _auth.currentUser;
//     if (user != null) {
//       DocumentReference userRef = _firestore.collection('users').doc(user.uid);

//       try {
//         await _firestore.runTransaction((transaction) async {
//           DocumentSnapshot userSnapshot = await transaction.get(userRef);
//           List<dynamic> tokens = userSnapshot['fcmTokens'] ?? [];

//           if (!tokens.contains(token)) {
//             transaction.update(userRef, {
//               'fcmTokens': FieldValue.arrayUnion([token]),
//             });
//             print('FCM Token saved to Firestore for user ${user.uid}');
//           } else {
//             print('FCM Token already exists for user ${user.uid}');
//           }
//         });
//       } catch (e) {
//         print('Error saving FCM token to Firestore: $e');
//       }
//     }
//   }


//    Future<void> _handleForegroundMessage(RemoteMessage message) async {
//     print('Received a message in the foreground: ${message.messageId}');
//     print('Message data: ${message.data}');

//     String notificationType = message.data['type'] ?? '';

//     if (notificationType == 'friend_request') {
//       // Friend request notification
//       await _showLocalNotification(RemoteNotification(
//         title: 'New Friend Request',
//         body: message.notification?.body ?? '',
//       ));
//     } else if (notificationType == 'new_participant') {
//       // Waiting Room notification
//       await _showLocalNotification(RemoteNotification(
//         title: 'New Ride Participant',
//         body: message.notification?.body ?? '',
//       ));
//     } else if (notificationType == 'chat_message' || notificationType == 'ride_chat_message') {
//       // Chat message notifications
//       await _showLocalNotification(RemoteNotification(
//         title: message.notification?.title ?? '',
//         body: message.notification?.body ?? '',
//       ));
//     } else if (message.notification != null) {
//       await _showLocalNotification(message.notification!);
//     }
//   }

//   Future<void> _showLocalNotification(RemoteNotification notification) async {
//     AndroidNotificationDetails androidDetails = const AndroidNotificationDetails(
//       'high_importance_channel',
//       'High Importance Notifications',
//       importance: Importance.max,
//       priority: Priority.high,
//     );
//     DarwinNotificationDetails iOSDetails = const DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//     );
//     NotificationDetails platformDetails = NotificationDetails(
//       android: androidDetails,
//       iOS: iOSDetails,
//     );

//     await _flutterLocalNotificationsPlugin.show(
//       notification.hashCode,
//       notification.title,
//       notification.body,
//       platformDetails,
//       payload: 'Default_Sound',
//     );
//   }

//   void _handleBackgroundMessage(RemoteMessage message) {
//     print('Handling a background message: ${message.messageId}');
//     // Implement any specific background message handling here
//   }

//   void _onNotificationTap(NotificationResponse response) {
//     // Handle notification tap here
//     print('Notification tapped: ${response.payload}');
//   }
// }

// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   print("Handling a background message: ${message.messageId}");
//   // Implement any specific background message handling here
// }

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

    await _requestPermissions();
    await _initializeLocalNotifications();
    await _configureFCM();
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

    String? token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
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
      }
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