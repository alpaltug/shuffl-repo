import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/group_details_screen/group_details_screen.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';

class GroupChatScreen extends StatefulWidget {
  final String chatId;
  final String chatType;

  const GroupChatScreen(
      {required this.chatId, required this.chatType, Key? key})
      : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _controller = TextEditingController();

  List<DocumentSnapshot> _participants = [];
  Map<String, Map<String, dynamic>> _participantsMap = {};
  String? currentUserImageUrl;
  String? currentUserUsername;
  String? groupTitle;
  bool _isLoading = true;
  bool _isReferralGroup = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _loadGroupDetails();
    await _loadParticipants();
    await _loadCurrentUserProfile();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadGroupDetails() async {
    try {
      DocumentSnapshot chatDoc = await _firestore
          .collection('${widget.chatType}_chats')
          .doc(widget.chatId)
          .get();

      if (chatDoc.exists) {
        Map<String, dynamic>? chatData =
            chatDoc.data() as Map<String, dynamic>?;

        groupTitle = chatData?['groupTitle'] ?? 'Group Chat';
        _isReferralGroup = widget.chatType == 'referral';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat does not exist.')),
        );
      }
    } catch (e) {
      print('Error loading group details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading group details: $e')),
      );
    }
  }

  Future<void> _loadParticipants() async {
    try {
      DocumentSnapshot chatDoc = await _firestore
          .collection('${widget.chatType}_chats')
          .doc(widget.chatId)
          .get();

      if (!chatDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat does not exist.')),
        );
        return;
      }

      List<String> participantUids =
          List<String>.from(chatDoc['participants'] ?? []);

      List<DocumentSnapshot> participantDocs = [];
      const int batchSize = 10;

      for (int i = 0; i < participantUids.length; i += batchSize) {
        final batch = participantUids.skip(i).take(batchSize).toList();
        QuerySnapshot querySnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        participantDocs.addAll(querySnapshot.docs);
      }

      setState(() {
        _participants = participantDocs;
        _participantsMap = {
          for (var doc in participantDocs)
            doc.id: {
              'username': doc['username'] ?? 'User',
              'imageUrl': doc['imageUrl'],
            }
        };
      });
    } catch (e) {
      print('Error loading participants: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading participants: $e')),
      );
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot currentUserDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (currentUserDoc.exists) {
          currentUserImageUrl = currentUserDoc['imageUrl'];
          currentUserUsername = currentUserDoc['username'] ?? 'Me';
        }
      } catch (e) {
        print('Error loading current user profile: $e');
      }
    }
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    String messageContent = _controller.text.trim();

    try {
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
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  ImageProvider<Object> _getProfileImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }
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
                  chatType: widget.chatType,
                  isReferralGroup: _isReferralGroup,
                ),
              ),
            );
          },
          child: Row(
            children: [
              ..._participants.take(3).map((participant) {
                String? imageUrl = participant['imageUrl'];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundImage: _getProfileImage(imageUrl),
                  ),
                );
              }).toList(),
              if (_participants.length > 3)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: CircleAvatar(
                    radius: 12,
                    child: Text(
                      '+',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
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

                  String senderName = isMe
                      ? (currentUserUsername ?? 'Me')
                      : (_participantsMap[senderId]?['username'] ?? 'User');
                  String? senderImageUrl = isMe
                      ? currentUserImageUrl
                      : _participantsMap[senderId]?['imageUrl'];

                  bool showUserInfo = false;
                  if (senderId != previousSenderId) {
                    showUserInfo = true;
                  }

                  previousSenderId = senderId;

                  if (senderId == 'system') {
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isMe)
                              if (showUserInfo)
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ViewUserProfile(
                                            uid: senderId),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  if (showUserInfo)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 2.0),
                                      child: Text(
                                        '@$senderName',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.7,
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
                                          color: isMe
                                              ? Colors.white
                                              : Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isMe) const SizedBox(width: 8),
                            if (isMe)
                              if (showUserInfo)
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
                                    backgroundImage:
                                        _getProfileImage(senderImageUrl),
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
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
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