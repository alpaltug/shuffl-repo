import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/group_chats_screen/group_chats_screen.dart';
import 'package:my_flutter_app/screens/friend_chat_screen/friend_chat_screen.dart';

class CreateChatScreen extends StatefulWidget {
  const CreateChatScreen({super.key});

  @override
  _CreateChatScreenState createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends State<CreateChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _selectedFriends = [];

  Future<List<Map<String, dynamic>>> _getFriends() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    List<String> friendUids = List<String>.from(userDoc['friends'] ?? []);

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

  Future<void> _createChat() async {
    if (_selectedFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one friend to create a chat.')),
      );
      return;
    }

    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    if (_selectedFriends.length == 1) {
      String friendUid = _selectedFriends[0];
      String chatId = _getChatId(currentUser.uid, friendUid);

      DocumentSnapshot chatSnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chats')
          .doc(chatId)
          .get();

      if (chatSnapshot.exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen(friendUid: friendUid)),
        );
      } else {
        await _createOneOnOneChat(currentUser.uid, friendUid, chatId);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ChatScreen(friendUid: friendUid)),
        );
      }
    } else {
      // Create a group chat
      List<String> participants = [currentUser.uid, ..._selectedFriends];
      participants.sort();
      String chatId = participants.join('_');

      for (String uid in participants) {
        DocumentSnapshot chatSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('chats')
            .doc(chatId)
            .get();

        if (chatSnapshot.exists) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => GroupChatScreen(chatId: chatId)),
          );
          return;
        }
      }

      Map<String, dynamic> newChatData = {
        'participants': participants,
        'lastMessage': {
          'content': '',
          'timestamp': FieldValue.serverTimestamp(),
        },
      };

      for (String uid in participants) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('chats')
            .doc(chatId)
            .set(newChatData);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => GroupChatScreen(chatId: chatId)),
      );
    }
  }

  String _getChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? '$uid1-$uid2' : '$uid2-$uid1';
  }

  Future<void> _createOneOnOneChat(String currentUserUid, String friendUid, String chatId) async {
    Map<String, dynamic> chatData = {
      'participants': [currentUserUid, friendUid],
      'lastMessage': {
        'content': '',
        'timestamp': FieldValue.serverTimestamp(),
      },
    };

    await _firestore
        .collection('users')
        .doc(currentUserUid)
        .collection('chats')
        .doc(chatId)
        .set(chatData);

    await _firestore
        .collection('users')
        .doc(friendUid)
        .collection('chats')
        .doc(chatId)
        .set(chatData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Chat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: kBackgroundColor,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: kBackgroundColor,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getFriends(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No friends found.'));
          }

          var friends = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _createChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Create Chat'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}