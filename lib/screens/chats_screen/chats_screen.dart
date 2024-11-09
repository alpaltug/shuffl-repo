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
                        if (chatSnapshot.connectionState == ConnectionState.waiting) {
                          // While loading, return an empty SizedBox to avoid showing 'Loading...'
                          return const SizedBox.shrink();
                        }

                        if (!chatSnapshot.hasData || !chatSnapshot.data!.exists) {
                          // If chat data is not available, skip this item
                          return const SizedBox.shrink();
                        }

                        var chatDoc = chatSnapshot.data!;
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
                                if (friendSnapshot.connectionState == ConnectionState.waiting) {
                                  // While loading, proceed to build the ListTile with default image
                                  profileImageUrl = null;
                                } else if (friendSnapshot.hasData && friendSnapshot.data!.exists) {
                                  var friendDoc = friendSnapshot.data!;
                                  var friendData = friendDoc.data() as Map<String, dynamic>;
                                  String friendName = friendData['username'] ?? 'Unknown User';
                                  String? friendImageUrl = friendData['imageUrl'];

                                  chatName = friendName;
                                  profileImageUrl = friendImageUrl;
                                } else {
                                  // If friend data is not available, use default values
                                  chatName = 'Unknown User';
                                  profileImageUrl = null;
                                }

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
                          String? lastMessageSenderUid =
                              chatData['lastMessage']?['senderId'];

                          Future<String?> getProfileImageUrl() async {
                            if (lastMessageSenderUid != null &&
                                lastMessageSenderUid != 'system') {
                              var senderDoc = await _firestore
                                  .collection('users')
                                  .doc(lastMessageSenderUid)
                                  .get();
                              if (senderDoc.exists) {
                                var senderData =
                                    senderDoc.data() as Map<String, dynamic>;
                                return senderData['imageUrl'] as String?;
                              }
                            }

                            List<String> otherParticipants = participants
                                .where((uid) =>
                                    uid != currentUserUid && uid != 'system')
                                .toList();

                            if (otherParticipants.isNotEmpty) {
                              String participantUid = otherParticipants.first;
                              var participantDoc = await _firestore
                                  .collection('users')
                                  .doc(participantUid)
                                  .get();
                              if (participantDoc.exists) {
                                var participantData =
                                    participantDoc.data() as Map<String, dynamic>;
                                return participantData['imageUrl'] as String?;
                              }
                            }

                            return null;
                          }

                          return FutureBuilder<String?>(
                            future: getProfileImageUrl(),
                            builder: (context, imageUrlSnapshot) {
                              if (imageUrlSnapshot.connectionState == ConnectionState.waiting) {
                                // While loading, proceed with default image
                                profileImageUrl = null;
                              } else {
                                profileImageUrl = imageUrlSnapshot.data;
                              }

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
                        }
                        // If none of the above, skip this chat
                        return const SizedBox.shrink();
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