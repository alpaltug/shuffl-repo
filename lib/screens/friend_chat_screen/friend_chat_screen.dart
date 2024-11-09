import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatType;

  const ChatScreen({required this.chatId, required this.chatType, Key? key})
      : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;

  String? friendUid;
  String? friendUsername;
  String? friendImageUrl;
  String? currentUserImageUrl;
  String? currentUserUsername;

  bool _isLoadingProfiles = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _fetchChatInfo();
    await _fetchProfiles();
  }

  Future<void> _fetchChatInfo() async {
    String collectionName = '${widget.chatType}_chats';
    DocumentSnapshot chatDoc =
        await _firestore.collection(collectionName).doc(widget.chatId).get();
    if (chatDoc.exists) {
      List<String> participants =
          List<String>.from(chatDoc['participants'] ?? []);
      String currentUserUid = _auth.currentUser!.uid;
      if (participants.length == 2) {
        friendUid = participants.firstWhere(
          (uid) => uid != currentUserUid,
          orElse: () => '',
        );
      }
    }
  }

  Future<void> _fetchProfiles() async {
    if (friendUid == null || friendUid!.isEmpty) {
      setState(() {
        _isLoadingProfiles = false;
      });
      return;
    }

    try {
      // Fetch friend's profile
      DocumentSnapshot friendProfile =
          await _firestore.collection('users').doc(friendUid).get();
      if (friendProfile.exists) {
        friendUsername = friendProfile['username'] ?? 'Unknown User';
        friendImageUrl = friendProfile['imageUrl'];
      } else {
        friendUsername = 'Unknown User';
      }

      // Fetch current user's profile
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot currentUserProfile =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (currentUserProfile.exists) {
          currentUserImageUrl = currentUserProfile['imageUrl'];
          currentUserUsername = currentUserProfile['username'] ?? 'Me';
        }
      }
    } catch (e) {
      print('Error fetching profiles: $e');
    } finally {
      setState(() {
        _isLoadingProfiles = false;
      });
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      String messageContent = _controller.text.trim();
      await _firestore
          .collection('${widget.chatType}_chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'senderId': currentUser.uid,
        'content': messageContent,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('${widget.chatType}_chats')
          .doc(widget.chatId)
          .update({
        'lastMessage': {
          'content': messageContent,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });

      _controller.clear();
    }

    setState(() {
      _isSending = false;
    });
  }

  ImageProvider<Object> _getProfileImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        return NetworkImage(imageUrl);
      } else {
        return AssetImage(imageUrl);
      }
    }
    return const AssetImage('assets/icons/ShuffleLogo.jpeg');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfiles) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (friendUid != null && friendUid!.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewUserProfile(uid: friendUid!),
                    ),
                  );
                }
              },
              child: CircleAvatar(
                backgroundImage: _getProfileImage(friendImageUrl),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              friendUsername ?? 'Unknown User',
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
        backgroundColor: kBackgroundColor,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('${widget.chatType}_chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'),
                  );
                }

                var messages = snapshot.data!.docs;
                User? currentUser = _auth.currentUser;

                List<Widget> messageWidgets = [];
                String? previousSenderId;

                for (var message in messages) {
                  var senderId = message['senderId'] ?? '';
                  var content = message['content'] ?? '';
                  var isMe = senderId == currentUser?.uid;

                  // Get sender's profile image
                  String? senderImageUrl = isMe
                      ? currentUserImageUrl
                      : friendImageUrl;

                  // Determine whether to display the profile picture
                  bool showProfilePic = false;
                  if (senderId != previousSenderId) {
                    // If the sender is different from the previous message, display the profile picture
                    showProfilePic = true;
                  }

                  previousSenderId = senderId;

                  if (senderId == 'system') {
                    // Display system messages as before
                    messageWidgets.add(
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        child: Center(
                          child: Text(
                            content,
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    messageWidgets.add(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isMe)
                              if (showProfilePic)
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ViewUserProfile(uid: friendUid!),
                                      ),
                                    );
                                  },
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundImage:
                                        _getProfileImage(senderImageUrl),
                                  ),
                                )
                              else
                                const SizedBox(width: 32),
                            if (!isMe) const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.blue : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Text(
                                  content,
                                  style: TextStyle(
                                      color:
                                          isMe ? Colors.white : Colors.black),
                                ),
                              ),
                            ),
                            if (isMe) const SizedBox(width: 8),
                            if (isMe)
                              if (showProfilePic)
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const UserProfile(),
                                      ),
                                    );
                                  },
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundImage: _getProfileImage(
                                        currentUserImageUrl),
                                  ),
                                )
                              else
                                const SizedBox(width: 32),
                          ],
                        ),
                      ),
                    );
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(10.0),
                  children: messageWidgets,
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
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 10.0, horizontal: 20.0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.black, width: 1.0),
                        borderRadius: BorderRadius.all(Radius.circular(20.0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.black, width: 2.0),
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