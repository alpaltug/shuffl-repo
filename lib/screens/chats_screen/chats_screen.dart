import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/friend_chat_screen/friend_chat_screen.dart';
import 'package:my_flutter_app/screens/create_chat_screen/create_chat_screen.dart';
import 'package:my_flutter_app/screens/group_chats_screen/group_chats_screen.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({Key? key}) : super(key: key);

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    String currentUserUid = _auth.currentUser!.uid;

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
          // Search Bar
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
          // Chats List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(currentUserUid)
                  .collection('userChats')
                  .snapshots(),
              builder: (context, userChatsSnapshot) {
                if (!userChatsSnapshot.hasData) {
                  return const Center(
                    child: LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'),
                  );
                }

                var userChats = userChatsSnapshot.data!.docs;

                if (userChats.isEmpty) {
                  return const Center(child: Text('No chats found.'));
                }

                return ListView.builder(
                  itemCount: userChats.length,
                  itemBuilder: (context, index) {
                    var userChat = userChats[index];
                    String chatId = userChat['chatId'];
                    String chatType = userChat['chatType']; 

                    String collectionName =
                        chatType == 'referral' ? 'referral_chats' : 'user_chats';

                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection(collectionName).doc(chatId).get(),
                      builder: (context, chatSnapshot) {
                        if (!chatSnapshot.hasData) {
                          return const ListTile(title: Text('Loading...'));
                        }

                        var chatDoc = chatSnapshot.data!;
                        if (!chatDoc.exists) {
                          return const ListTile(title: Text('Chat does not exist.'));
                        }

                        var chatData = chatDoc.data() as Map<String, dynamic>;

                        bool isGroupChat = chatData['isGroupChat'] ?? false;
                        String chatName = isGroupChat
                            ? chatData['groupTitle'] ?? 'Group Chat'
                            : 'Chat'; 

                        String? profileImageUrl;
                        List<String> participants =
                            List<String>.from(chatData['participants'] ?? []);
                        String currentUserUid = _auth.currentUser!.uid;
                        String? friendUid;

                        if (!isGroupChat && participants.length == 2) {
                          friendUid = participants
                              .firstWhere((uid) => uid != currentUserUid, orElse: () => '');
                          if (friendUid.isNotEmpty) {
                            return FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('users').doc(friendUid).get(),
                              builder: (context, friendSnapshot) {
                                if (!friendSnapshot.hasData) {
                                  return const ListTile(title: Text('Loading...'));
                                }

                                var friendDoc = friendSnapshot.data!;
                                if (!friendDoc.exists) {
                                  return const ListTile(title: Text('User does not exist.'));
                                }

                                var friendData = friendDoc.data() as Map<String, dynamic>;
                                String friendName = friendData['username'] ?? 'Unknown User';
                                String? friendImageUrl = friendData['imageUrl'];

                                chatName = friendName;
                                profileImageUrl = friendImageUrl;

                                if (_searchQuery.isNotEmpty &&
                                    !chatName.toLowerCase().contains(_searchQuery)) {
                                  return const SizedBox.shrink();
                                }

                                return ListTile(
                                  leading: _buildAvatar(profileImageUrl),
                                  title: Text(
                                    chatName,
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                  subtitle: Text(
                                    chatData['lastMessage']?['content'] ?? 'No message',
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatScreen(
                                          chatId: chatId,
                                          chatType: chatType,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          }
                        } else if (isGroupChat) {
                          String? lastMessageSenderUid = chatData['lastMessage']?['senderId'];

                          if (lastMessageSenderUid != null &&
                              lastMessageSenderUid != 'system') {
                            return FutureBuilder<DocumentSnapshot>(
                              future: _firestore.collection('users').doc(lastMessageSenderUid).get(),
                              builder: (context, senderSnapshot) {
                                if (!senderSnapshot.hasData) {
                                  return const ListTile(title: Text('Loading...'));
                                }

                                var senderDoc = senderSnapshot.data!;
                                if (!senderDoc.exists) {
                                  return const ListTile(title: Text('User does not exist.'));
                                }

                                var senderData = senderDoc.data() as Map<String, dynamic>;
                                String? senderImageUrl = senderData['imageUrl'];

                                profileImageUrl = senderImageUrl;

                                chatName = chatData['groupTitle'] ?? 'Group Chat';

                                if (_searchQuery.isNotEmpty &&
                                    !chatName.toLowerCase().contains(_searchQuery)) {
                                  return const SizedBox.shrink();
                                }

                                return ListTile(
                                  leading: _buildAvatar(profileImageUrl),
                                  title: Text(
                                    chatName,
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                  subtitle: Text(
                                    chatData['lastMessage']?['content'] ?? 'No message',
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => GroupChatScreen(
                                          chatId: chatId,
                                          chatType: chatType,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          } else {
                            chatName = chatData['groupTitle'] ?? 'Group Chat';

                            if (_searchQuery.isNotEmpty &&
                                !chatName.toLowerCase().contains(_searchQuery)) {
                              return const SizedBox.shrink();
                            }

                            return ListTile(
                              leading: _buildAvatar(profileImageUrl),
                              title: Text(
                                chatName,
                                style: const TextStyle(color: Colors.black),
                              ),
                              subtitle: Text(
                                chatData['lastMessage']?['content'] ?? 'No message',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GroupChatScreen(
                                      chatId: chatId,
                                      chatType: chatType,
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        }
                        return const ListTile(title: Text('Chat'));
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
}