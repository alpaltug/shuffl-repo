import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/chats_screen/chats_screen.dart'; // Ensure this import points to the correct path for the ChatsScreen

class AddUsersToGroupScreen extends StatefulWidget {
  final String chatId;
  final List<DocumentSnapshot> currentParticipants;

  const AddUsersToGroupScreen({
    Key? key,
    required this.chatId,
    required this.currentParticipants,
  }) : super(key: key);

  @override
  _AddUsersToGroupScreenState createState() => _AddUsersToGroupScreenState();
}

class _AddUsersToGroupScreenState extends State<AddUsersToGroupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _selectedFriends = [];
  List<String> _excludedFriends = [];

  @override
  void initState() {
    super.initState();
    _excludedFriends = widget.currentParticipants.map((doc) => doc.id).toList();
  }

  Future<List<Map<String, dynamic>>> _getFriends() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    List<String> friendUids = List<String>.from(userDoc['friends'] ?? []);

    // Filter out friends who are already in the group
    friendUids = friendUids.where((uid) => !_excludedFriends.contains(uid)).toList();

    List<Map<String, dynamic>> friends = [];
    for (String uid in friendUids) {
      DocumentSnapshot friendDoc = await _firestore.collection('users').doc(uid).get();
      if (friendDoc.exists) {
        friends.add({
          'uid': uid,
          'username': friendDoc['username'],
          'imageUrl': friendDoc['imageUrl'],
        });
      }
    }

    return friends;
  }

  Future<void> _addSelectedFriendsToGroup() async {
    if (_selectedFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select friends to add to the group.')),
      );
      return;
    }

    // Cast the first participant's data to a Map
    Map<String, dynamic>? groupData = widget.currentParticipants.first.data() as Map<String, dynamic>?;

    String groupTitle = groupData?['groupTitle'] ?? 'Unnamed Group'; // Safely retrieve groupTitle

    for (String uid in _selectedFriends) {
      // Add the group chat to each selected friend's chat collection
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(widget.chatId)
          .set({
        'participants': FieldValue.arrayUnion([uid]),
        'isGroupChat': true,
        'groupTitle': groupTitle, // Use the safely retrieved groupTitle
        'lastMessage': {
          'content': '',
          'timestamp': FieldValue.serverTimestamp(),
        },
      });

      // Update the group chat document for all existing participants
      for (String participantUid in widget.currentParticipants.map((doc) => doc.id).toList()) {
        await _firestore
            .collection('users')
            .doc(participantUid)
            .collection('chats')
            .doc(widget.chatId)
            .update({
          'participants': FieldValue.arrayUnion([uid]),
        });
      }
    }

    // Navigate to the Chats screen after adding friends
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const ChatsScreen()),
      (route) => false, // Remove all routes until ChatsScreen
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Friends',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: kBackgroundColor,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getFriends(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No friends available to add.'));
          }

          var friends = snapshot.data!;

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              var friend = friends[index];
              var friendUid = friend['uid'];
              var friendUsername = friend['username'];
              var friendImageUrl = friend['imageUrl'];

              return CheckboxListTile(
                value: _selectedFriends.contains(friendUid),
                onChanged: (selected) {
                  setState(() {
                    if (selected!) {
                      _selectedFriends.add(friendUid);
                    } else {
                      _selectedFriends.remove(friendUid);
                    }
                  });
                },
                title: Text(
                  friendUsername,
                  style: const TextStyle(color: Colors.black),
                ),
                checkColor: Colors.black,
                activeColor: kBackgroundColor,
                secondary: CircleAvatar(
                  backgroundImage: friendImageUrl != null && friendImageUrl.isNotEmpty
                      ? NetworkImage(friendImageUrl)
                      : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _addSelectedFriendsToGroup,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey, // Grey background for the button
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
          child: const Text(
            'Add Friends',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}