import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/add_user_to_group_screen/add_user_to_group_screen.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';

class GroupDetailScreen extends StatefulWidget {
  final String chatId;
  final List<DocumentSnapshot> participants;

  GroupDetailScreen({required this.chatId, required this.participants});

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _leaveGroup() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .doc(widget.chatId)
        .delete();

    Navigator.pop(context);
  }

  ImageProvider<Object> _getProfileImage(String? imageUrl) {
    // Use default image if imageUrl is null or empty
    if (imageUrl == null || imageUrl.isEmpty) {
      return const AssetImage('assets/icons/ShuffleLogo.jpeg');
    }
    return NetworkImage(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 1,
        title: const Text(
          'Group Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddUsersToGroupScreen(
                    chatId: widget.chatId,
                    currentParticipants: widget.participants,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.participants.length,
              itemBuilder: (context, index) {
                var participant = widget.participants[index];
                var imageUrl = participant['imageUrl'] ?? '';
                var username = participant['username'] ?? 'User';
                var uid = participant.id;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: _getProfileImage(imageUrl),
                  ),
                  title: Text(
                    username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    // Navigate to the user profile when tapped
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewUserProfile(uid: uid),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: _leaveGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text(
                'Leave Group',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}