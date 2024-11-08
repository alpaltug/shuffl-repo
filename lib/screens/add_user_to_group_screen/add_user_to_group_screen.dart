import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/chats_screen/chats_screen.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';

class AddUsersToGroupScreen extends StatefulWidget {
  final String chatId;
  final String chatType; 
  final List<DocumentSnapshot> currentParticipants;

  const AddUsersToGroupScreen({
    Key? key,
    required this.chatId,
    required this.chatType,
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
  bool _isSubmitting = false;

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
    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_selectedFriends.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select friends to add to the group.')),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      List<String> allParticipants = [
        ...widget.currentParticipants.map((doc) => doc.id),
        ..._selectedFriends,
      ];

      print('All participants: $allParticipants');

      String chatId = widget.chatId;
      String chatType = widget.chatType;

      DocumentReference chatRef = _firestore.collection('${chatType}_chats').doc(chatId);
      DocumentSnapshot chatDoc = await chatRef.get();

      if (!chatDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat does not exist.')),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
      String groupTitle = chatData['groupTitle'] ?? 'Group Chat';

      await chatRef.update({
        'participants': allParticipants,
        'lastMessage': {
          'content': 'Group updated with new members',
          'timestamp': FieldValue.serverTimestamp(),
        },
      });

      await chatRef.collection('messages').add({
        'senderId': 'system',
        'content': 'New members have been added to the group',
        'timestamp': FieldValue.serverTimestamp(),
      });

      WriteBatch batch = _firestore.batch();

      for (String uid in _selectedFriends) {
        DocumentReference userChatRef = _firestore.collection('users').doc(uid).collection('userChats').doc(chatId);
        batch.set(userChatRef, {
          'chatId': chatId,
          'chatType': chatType,
          'groupTitle': groupTitle,
          'participants': allParticipants,
          'lastMessage': {
            'content': 'Joined the group',
            'timestamp': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      }

      for (DocumentSnapshot doc in widget.currentParticipants) {
        String uid = doc.id;
        DocumentReference userChatRef = _firestore.collection('users').doc(uid).collection('userChats').doc(chatId);
        batch.set(userChatRef, {
          'participants': allParticipants,
          'lastMessage': {
            'content': 'Group updated with new members',
            'timestamp': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${_selectedFriends.length} friends to the group.')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()), 
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
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
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
          onPressed: _isSubmitting ? null : _addSelectedFriendsToGroup,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                )
              : const Text(
                  'Add Friends',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}