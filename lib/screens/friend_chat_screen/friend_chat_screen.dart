import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';


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
  String? currentUserImageUrl;
  bool _isSending = false;


  @override
  void initState() {
    super.initState();
    _initializeChat();
    _fetchProfiles();
  }

  void _initializeChat() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      chatId = _getChatId(currentUser.uid, widget.friendUid);
      _firestoreService.markMessagesAsRead(chatId, currentUser.uid);
      setState(() {});
    }
  }

  void _fetchProfiles() async {
    // Fetch friend profile
    DocumentSnapshot friendProfile =
        await _firestore.collection('users').doc(widget.friendUid).get();
    if (friendProfile.exists) {
      setState(() {
        friendUsername = friendProfile['username'];
        friendImageUrl = friendProfile['imageUrl'];
      });
    }

    // Fetch current user profile
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot currentUserProfile =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (currentUserProfile.exists) {
        setState(() {
          currentUserImageUrl = currentUserProfile['imageUrl'];
        });
      }
    }
  }

  String _getChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? '$uid1-$uid2' : '$uid2-$uid1';
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty || _isSending) return;

    _isSending = true; // Disable sending temporarily

    print("Sending message: ${_controller.text}");

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      // Get the server timestamp
      final timestamp = FieldValue.serverTimestamp();

      // Pass the timestamp to the sendMessage method
      await _firestoreService.sendMessage(
          chatId, currentUser.uid, widget.friendUid, _controller.text, timestamp);

      // Mark the message as read for the sender
      await _firestoreService.markMessagesAsRead(chatId, currentUser.uid);

      _controller.clear();
    }
    _isSending = false; // Enable sending
  }


  ImageProvider<Object> _getProfileImage(String? imageUrl) {
    // Always use the imageUrl from Firestore.
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }
    // Use the default Shuffle logo if imageUrl is invalid.
    return const AssetImage('assets/icons/ShuffleLogo.jpeg');
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
                backgroundImage: _getProfileImage(friendImageUrl), // Use imageUrl from Firestore
              ),
            ),
            const SizedBox(width: 10),
            Text(friendUsername ?? 'Shuffl User',
                style: const TextStyle(color: Colors.black)), // Set text color to black
          ],
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
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'), // Add your logo path here
                  );
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
                                    builder: (context) =>
                                        ViewUserProfile(uid: widget.friendUid),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                backgroundImage: _getProfileImage(friendImageUrl),
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
                    style: const TextStyle(color: Colors.black), // Set the text color to black
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.black),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0), // Move the text up
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