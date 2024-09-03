import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/group_details_screen/group_details_screen.dart';
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
  String? currentUserImageUrl;
  String? groupTitle;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    _loadCurrentUserImage();
    _loadGroupTitle();
  }

  Future<void> _loadParticipants() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    DocumentSnapshot chatDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .doc(widget.chatId)
        .get();

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
        _isLoading = false;  
      });
    }
  }

  Future<void> _loadCurrentUserImage() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (currentUserDoc.exists) {
        setState(() {
          currentUserImageUrl = currentUserDoc['imageUrl'];
        });
      }
    }
  }

  Future<void> _loadGroupTitle() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    DocumentSnapshot chatDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .doc(widget.chatId)
        .get();

    if (chatDoc.exists) {
      setState(() {
        groupTitle = chatDoc['groupTitle'];
      });
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    String messageContent = _controller.text.trim();

    // Add the message to each participant's chat subcollection
    for (String uid in _participants.map((doc) => doc.id).toList()) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'content': messageContent,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // Update the last message in each participant's chat document
    for (String uid in _participants.map((doc) => doc.id).toList()) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': {
          'content': messageContent,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });
    }

    _controller.clear();
  }

  ImageProvider<Object> _getProfileImage(String? imageUrl) {
    // Check if the image URL is valid and use it directly if it is.
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }
    // Use the default asset image when the URL is invalid.
    return const AssetImage('assets/icons/ShuffleLogo.jpeg');
  }

    @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailScreen(
                  chatId: widget.chatId,
                  participants: _participants,
                ),
              ),
            );
          },
          child: Row(
            children: [
              ..._participants.map((participant) {
                String? imageUrl = participant['imageUrl'];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundImage: _getProfileImage(imageUrl),
                  ),
                );
              }).toList(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  groupTitle ?? 'Group Chat',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black, 
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
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
                  .collection('users')
                  .doc(_auth.currentUser!.uid)
                  .collection('chats')
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
                    var sender = _participants.firstWhere((p) => p.id == senderId, orElse: () => _participants[0]);
                    var senderName = sender['username'] ?? 'User';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      title: !isMe
                          ? Text(
                              senderName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54),
                            )
                          : null,
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
                                backgroundImage: _getProfileImage(currentUserImageUrl),
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
                                backgroundImage: _getProfileImage(sender['imageUrl']),
                              ),
                            )
                          : null,
                      subtitle: Align(
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