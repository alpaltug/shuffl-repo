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
  String? _groupTitle;

  // Fetch friends only once to avoid unnecessary refreshes
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
    // Handle one-on-one chat creation (keep existing logic)
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
    // Create a new group chat
    if (_groupTitle == null || _groupTitle!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group title.')),
      );
      return;
    }

    List<String> participants = [currentUser.uid, ..._selectedFriends];
    String chatId = DateTime.now().millisecondsSinceEpoch.toString(); // Generate a unique chatId

    Map<String, dynamic> newChatData = {
      'participants': participants,
      'groupTitle': _groupTitle,
      'isGroupChat': true,
      'lastMessage': {
        'content': 'Group created',
        'timestamp': FieldValue.serverTimestamp(),
      },
    };

    // Create the group chat document in Firestore
    await _firestore.collection('group_chats').doc(chatId).set(newChatData);

    // Add the chat to each participant's chats collection
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
      'isGroupChat': false,
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
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No friends found.'));
          }

          var friends = snapshot.data!;

          return Column(
            children: [
              if (_selectedFriends.length > 1)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (value) {
                      _groupTitle = value;
                    },
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Group Title',
                      labelStyle: const TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: const BorderSide(color: Colors.black, width: 2.0),
                      ),
                    ),
                  ),
                ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 15),
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