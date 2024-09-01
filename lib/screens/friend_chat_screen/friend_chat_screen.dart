import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';

class ChatScreen extends StatefulWidget {
  final String friendUid;

  ChatScreen({required this.friendUid});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _controller = TextEditingController();
  late String chatId;
  String? friendUsername;
  String? friendImageUrl;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _fetchFriendProfile();
  }

  void _initializeChat() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      chatId = _getChatId(currentUser.uid, widget.friendUid);
      _firestoreService.markMessagesAsRead(chatId, currentUser.uid);
      setState(() {});
    }
  }

  void _fetchFriendProfile() async {
    DocumentSnapshot friendProfile = await _firestore.collection('users').doc(widget.friendUid).get();
    if (friendProfile.exists) {
      setState(() {
        friendUsername = friendProfile['username'];
        friendImageUrl = friendProfile['imageUrl'];
      });
    }
  }

  String _getChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? '$uid1-$uid2' : '$uid2-$uid1';
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _firestoreService.sendMessage(chatId, currentUser.uid, widget.friendUid, _controller.text);
      // Mark the message as read for the sender
      await _firestoreService.markMessagesAsRead(chatId, currentUser.uid);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBackgroundColor, // Set background color to yellow
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewUserProfile(uid: widget.friendUid),
                  ),
                );
              },
              child: CircleAvatar(
                backgroundImage: friendImageUrl != null && friendImageUrl!.isNotEmpty
                    ? NetworkImage(friendImageUrl!)
                    : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
              ),
            ),
            const SizedBox(width: 10),
            Text(friendUsername ?? 'Shuffl User', style: const TextStyle(color: Colors.black)), // Set text color to black
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').doc(_auth.currentUser!.uid)
                  .collection('chats').doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    var isMe = message['senderId'] == _auth.currentUser!.uid;

                    return ListTile(
                      trailing: isMe
                          ? GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const UserProfile(),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                backgroundImage: _auth.currentUser!.photoURL != null && _auth.currentUser!.photoURL!.isNotEmpty
                                    ? NetworkImage(_auth.currentUser!.photoURL!)
                                    : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                              ),
                            )
                          : null,
                      leading: !isMe
                          ? GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ViewUserProfile(uid: widget.friendUid),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                backgroundImage: friendImageUrl != null && friendImageUrl!.isNotEmpty
                                    ? NetworkImage(friendImageUrl!)
                                    : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                              ),
                            )
                          : null,
                      title: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            message['content'],
                            style: TextStyle(color: isMe ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.black),  // Set the text color to black
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.black), 
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0), // Move the text up
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}