import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';

class GroupChatScreen extends StatefulWidget {
  final String rideId;

  GroupChatScreen({required this.rideId});

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();
  late String chatId;
  List<DocumentSnapshot> _users = [];
  Map<String, String> _userProfilePictures = {};

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _loadParticipants();
  }

  void _initializeChat() {
    chatId = widget.rideId;
    setState(() {});
  }

  Future<void> _loadParticipants() async {
    DocumentSnapshot rideDoc = await _firestore.collection('active_rides').doc(widget.rideId).get();
    List<String> userIds = List<String>.from(rideDoc['participants']);

    List<DocumentSnapshot> userDocs = [];
    for (String uid in userIds) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        userDocs.add(userDoc);
        _userProfilePictures[uid] = userDoc['imageUrl'] ?? '';
      }
    }

    setState(() {
      _users = userDocs;
    });
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _firestore.collection('active_rides').doc(widget.rideId)
          .collection('messages').add({
        'senderId': currentUser.uid,
        'content': _controller.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _controller.clear();
    }
  }

  void _showParticipants(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Participants',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  var user = _users[index];
                  var username = user['username'] ?? '';
                  var fullName = user['fullName'] ?? '';
                  var imageUrl = user.data().toString().contains('imageUrl') ? user['imageUrl'] : null;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                    ),
                    title: Text(fullName, style: const TextStyle(color: Colors.black)),
                    subtitle: Text('@$username', style: const TextStyle(color: Colors.black)),
                    onTap: () {
                      User? currentUser = _auth.currentUser;
                      if (user.id == currentUser?.uid) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserProfile(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewUserProfile(uid: user.id),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text('Group Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () => _showParticipants(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('active_rides').doc(widget.rideId)
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
                    var senderId = message['senderId'];
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
                                backgroundImage: _userProfilePictures[senderId] != null && _userProfilePictures[senderId]!.isNotEmpty
                                    ? NetworkImage(_userProfilePictures[senderId]!)
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
                                backgroundImage: _userProfilePictures[senderId] != null && _userProfilePictures[senderId]!.isNotEmpty
                                    ? NetworkImage(_userProfilePictures[senderId]!)
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
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.black),
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
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