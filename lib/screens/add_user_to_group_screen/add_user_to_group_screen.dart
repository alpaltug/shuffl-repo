import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/chats_screen/chats_screen.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';

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
    print('Excluded friends: $_excludedFriends');
  }

  Future<List<Map<String, dynamic>>> _getFriends() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('No current user found');
        return [];
      }

      print('Fetching user document for ${currentUser.uid}');
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Failed to fetch user document');
        },
      );

      List<String> friendUids = List<String>.from(userDoc['friends'] ?? []);
      print('All friend UIDs: $friendUids');

      friendUids = friendUids.where((uid) => !_excludedFriends.contains(uid)).toList();
      print('Filtered friend UIDs: $friendUids');

      List<Map<String, dynamic>> friends = [];
      for (String uid in friendUids) {
        try {
          print('Fetching friend document for $uid');
          DocumentSnapshot friendDoc = await _firestore.collection('users').doc(uid).get().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Failed to fetch friend document');
            },
          );
          if (friendDoc.exists) {
            friends.add({
              'uid': uid,
              'username': friendDoc['username'],
              'imageUrl': friendDoc['imageUrl'],
            });
          } else {
            print('Friend document for $uid does not exist');
          }
        } catch (e) {
          print('Error fetching friend $uid: $e');
        }
      }

      print('Fetched ${friends.length} friends');
      return friends;
    } catch (e) {
      print('Error in _getFriends: $e');
      rethrow;
    }
  }

 Future<void> _addSelectedFriendsToGroup() async {
  try {
    if (_selectedFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select friends to add to the group.')),
      );
      return;
    }

    List<String> allParticipants = [
      ...widget.currentParticipants.map((doc) => doc.id),
      ..._selectedFriends,
    ];

    print('All participants: $allParticipants');

    String chatId = widget.chatId;
    bool isExistingGroupChat = false;
    DocumentSnapshot? groupChatDoc;

    // Check if this is already a group chat
    try {
      groupChatDoc = await _firestore.collection('group_chats').doc(chatId).get();
      isExistingGroupChat = groupChatDoc.exists;
    } catch (e) {
      print('Error checking existing group chat: $e');
      isExistingGroupChat = false;
    }

    if (isExistingGroupChat) {
      // Update the existing group chat
      await _firestore.collection('group_chats').doc(chatId).update({
        'participants': allParticipants,
      });
      print('Updated existing group chat: $chatId');

      // Fetch the updated document
      groupChatDoc = await _firestore.collection('group_chats').doc(chatId).get();
    } else {
      // If the group does not exist, show an error message and stop further execution
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group chat does not exist.')),
      );
      return;
    }

    Map<String, dynamic> groupChatData = groupChatDoc.data() as Map<String, dynamic>;
    String groupTitle = groupChatData['groupTitle'] ?? 'Group Chat';

    // Update or create chat documents for all participants
    for (String uid in allParticipants) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(chatId)
          .set({
        'isGroupChat': true,
        'groupTitle': groupTitle,
        'participants': allParticipants,
        'lastMessage': groupChatData['lastMessage'] ?? {
          'content': 'Group updated',
          'timestamp': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
      print('Updated chat document for user: $uid');
    }

    // Navigate back to the Chats screen
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ChatsScreen()),
        (route) => false,
      );
    }
  } catch (e) {
    print('Error in _addSelectedFriendsToGroup: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }
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
            return const Center(
              child: LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'),
            );
          }

          if (snapshot.hasError) {
            print('Error in FutureBuilder: ${snapshot.error}');
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
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
                  print('Selected friends: $_selectedFriends');
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
            backgroundColor: Colors.grey,
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