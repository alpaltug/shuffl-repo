import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/friend_chat_screen/friend_chat_screen.dart';
import 'package:my_flutter_app/screens/create_chat_screen/create_chat_screen.dart';
import 'package:my_flutter_app/screens/group_chats_screen/group_chats_screen.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/firestore_service.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: kBackgroundColor,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CreateChatScreen()),
              );
            },
          ),
        ],
      ),
      backgroundColor: kBackgroundColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: const TextStyle(color: Colors.black),
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_auth.currentUser!.uid)
                  .collection('chats')
                  .orderBy('lastMessage.timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var chats = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    var chat = chats[index];
                    var participants = List<String>.from(chat['participants']);
                    var isGroupChat = participants.length > 2;
                    String currentUserUid = _auth.currentUser!.uid;

                    return FutureBuilder<Map<String, dynamic>>(
                      future: _getChatInfo(participants, currentUserUid, isGroupChat),
                      builder: (context, chatInfoSnapshot) {
                        if (!chatInfoSnapshot.hasData) {
                          return const ListTile(title: Text('Loading...'));
                        }

                        var chatInfo = chatInfoSnapshot.data!;
                        var chatName = chatInfo['name'];
                        var profileImageUrl = chatInfo['imageUrl'];

                        return ListTile(
                          leading: _buildAvatar(profileImageUrl),
                          title: Text(
                            chatName,
                            style: const TextStyle(color: Colors.black),
                          ),
                          subtitle: Text(
                            chat['lastMessage']?['content'] ?? 'No message',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          onTap: () {
                            if (isGroupChat) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GroupChatScreen(chatId: chat.id),
                                ),
                              );
                            } else {
                              String friendUid = participants.firstWhere((uid) => uid != currentUserUid);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(friendUid: friendUid),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/icons/ShuffleLogo.jpeg',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  );
                },
              )
            : Image.asset(
                'assets/icons/ShuffleLogo.jpeg',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getChatInfo(List<String> participants, String currentUserUid, bool isGroupChat) async {
    if (isGroupChat) {
      List<String> usernames = await _firestoreService.getParticipantUsernames(
        participants.where((uid) => uid != currentUserUid).toList()
      );
      String name = usernames.join(', ');
      String? imageUrl = await _firestoreService.getFirstParticipantImageUrl(participants, currentUserUid);
      return {'name': name, 'imageUrl': imageUrl};
    } else {
      String friendUid = participants.firstWhere((uid) => uid != currentUserUid);
      DocumentSnapshot friendProfile = await _firestore.collection('users').doc(friendUid).get();
      String name = friendProfile['username'] ?? 'Unknown User';
      String? imageUrl = friendProfile['imageUrl'];
      return {'name': name, 'imageUrl': imageUrl};
    }
  }
}