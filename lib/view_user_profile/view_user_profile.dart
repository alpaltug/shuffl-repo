import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/firestore_service.dart';

class ViewUserProfile extends StatefulWidget {
  final String uid;
  const ViewUserProfile({super.key, required this.uid});

  @override
  _ViewUserProfileState createState() => _ViewUserProfileState();
}

class _ViewUserProfileState extends State<ViewUserProfile> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  DocumentSnapshot? userProfile;
  bool isLoading = true;
  String? _displayName;
  String? _username;
  String? _description;
  String? _imageUrl;
  bool isFriendRequestSent = false;
  bool isAlreadyFriend = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkFriendStatus();
  }

  void _loadUserProfile() async {
    try {
      userProfile = await _firestore.collection('users').doc(widget.uid).get();
      if (userProfile != null) {
        setState(() {
          _displayName = userProfile!['fullName'] ?? '';
          _username = userProfile!['username'] ?? '';
          _description = userProfile!['description'] ?? '';
          _imageUrl = userProfile!.data().toString().contains('imageUrl') ? userProfile!['imageUrl'] : null;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _checkFriendStatus() async {
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      // Check if the current user and the viewed user are already friends
      DocumentSnapshot currentUserSnapshot = await _firestore.collection('users').doc(currentUser.uid).get();
      List friends = currentUserSnapshot.data().toString().contains('friends')
          ? List.from(currentUserSnapshot['friends'])
          : [];
      if (friends.contains(widget.uid)) {
        setState(() {
          isAlreadyFriend = true;
        });
        return;
      }

      // Check if a friend request has already been sent
      QuerySnapshot sentRequests = await _firestore
          .collection('users')
          .doc(widget.uid)
          .collection('notifications')
          .where('fromUid', isEqualTo: currentUser.uid)
          .where('type', isEqualTo: 'friend_request')
          .get();
      if (sentRequests.docs.isNotEmpty) {
        setState(() {
          isFriendRequestSent = true;
        });
      }
    }
  }

  void _addFriend() async {
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      await _firestoreService.sendFriendRequest(currentUser.uid, widget.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );
      setState(() {
        isFriendRequestSent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LogoAppBar(
        title: 'User Profile',
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: null, // Add navigation to search users page if needed
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _imageUrl != null && _imageUrl!.isNotEmpty
                        ? NetworkImage(_imageUrl!)
                        : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _displayName ?? '',
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '@$_username',
                    style: const TextStyle(
                        fontSize: 20, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _description ?? '',
                    style: const TextStyle(
                        fontSize: 16, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  GreenActionButton(
                    text: isAlreadyFriend
                        ? 'Already Friends'
                        : isFriendRequestSent
                            ? 'Request Sent'
                            : 'Add Friend',
                    onPressed: () {
                      if (!isAlreadyFriend && !isFriendRequestSent) {
                        _addFriend();
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}