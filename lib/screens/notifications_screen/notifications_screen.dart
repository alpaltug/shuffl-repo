import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/widgets.dart';
import 'package:my_flutter_app/constants.dart'; // Import for constants

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  User? currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = _auth.currentUser;
  }

  void _acceptRequest(String notificationId, String fromUid) async {
    if (currentUser != null) {
      await _firestoreService.acceptFriendRequest(currentUser!.uid, fromUid);
      await _firestoreService.declineFriendRequest(notificationId, currentUser!.uid);
    }
  }

  void _declineRequest(String notificationId) async {
    if (currentUser != null) {
      await _firestoreService.declineFriendRequest(notificationId, currentUser!.uid);
    }
  }

  Future<String> _getUsername(String uid) async {
    DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(uid).get();
    return userSnapshot['username'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LogolessAppBar(
        title: 'Notifications',
        automaticallyImplyLeading: true, // Include necessary buttons
      ),
      backgroundColor: kBackgroundColor, // Set the background color to match the app's theme
      body: currentUser == null
          ? const Center(
              child: Text(
                'No user logged in',
                style: TextStyle(color: Colors.black), // Set text color to black
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').doc(currentUser!.uid).collection('notifications').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var notifications = snapshot.data!.docs;

                if (notifications.isEmpty) {
                  return const Center(
                    child: Text(
                      'No notifications',
                      style: TextStyle(color: Colors.black), // Set text color to black
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    var notification = notifications[index];
                    var fromUid = notification['fromUid'];
                    var notificationId = notification.id;

                    return FutureBuilder<String>(
                      future: _getUsername(fromUid),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ListTile(
                            title: Text(
                              'Loading...',
                              style: TextStyle(color: Colors.black), // Set text color to black
                            ),
                          );
                        }

                        var username = snapshot.data!;
                        return ListTile(
                          title: Text(
                            'Friend request from @$username',
                            style: const TextStyle(color: Colors.black), // Set text color to black
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () => _acceptRequest(notificationId, fromUid),
                                child: const Text(
                                  'Accept',
                                  style: TextStyle(color: Colors.black), // Set button text color to black
                                ),
                              ),
                              TextButton(
                                onPressed: () => _declineRequest(notificationId),
                                child: const Text(
                                  'Decline',
                                  style: TextStyle(color: Colors.black), // Set button text color to black
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}