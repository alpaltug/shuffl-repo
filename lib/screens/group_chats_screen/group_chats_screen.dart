import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';

class GroupChatScreen extends StatefulWidget {
  final String chatId;

  GroupChatScreen({required this.chatId});

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();
  List<DocumentSnapshot> _participants = [];

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    DocumentSnapshot chatDoc = await _firestore.collection('group_chats').doc(widget.chatId).get();
    if (chatDoc.exists) {
      List<String> participantUids = List<String>.from(chatDoc['participants'] ?? []);

      List<DocumentSnapshot> participantDocs = [];
      for (String uid in participantUids) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          participantDocs.add(userDoc);
        }
      }

      setState(() {
        _participants = participantDocs;
      });
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('group_chats').doc(widget.chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'content': _controller.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('group_chats').doc(widget.chatId).update({
      'lastMessage': {
        'content': _controller.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      },
    });

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: _participants.isNotEmpty && _participants[0]['imageUrl'] != null
                    ? NetworkImage(_participants[0]['imageUrl'])
                    : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
              ),
              const SizedBox(width: 8),
              Text(
                _participants.map((p) => p['username'] ?? 'Unknown').join(', '),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('group_chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;
                User? currentUser = _auth.currentUser;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index];
                    var senderId = message['senderId'] ?? '';
                    var content = message['content'] ?? '';
                    var isMe = senderId == currentUser?.uid;

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
                                backgroundImage: currentUser?.photoURL != null
                                    ? NetworkImage(currentUser!.photoURL!)
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
                                    builder: (context) => ViewUserProfile(uid: senderId),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                backgroundImage: _participants.any((p) => p.id == senderId)
                                    ? NetworkImage(
                                        _participants.firstWhere((p) => p.id == senderId)['imageUrl'] ?? '',
                                      )
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
                            content,
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
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.black),
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 1.0),
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black, width: 2.0),
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}