import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/friend_chat_screen/friend_chat_screen.dart';
import 'package:my_flutter_app/screens/create_chat_screen/create_chat_screen.dart';
import 'package:my_flutter_app/constants.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  Future<String> _getFriendUsername(String friendUid) async {
    DocumentSnapshot userSnapshot =
        await _firestore.collection('users').doc(friendUid).get();
    return userSnapshot.get('username') ?? 'Unknown';
  }

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
                MaterialPageRoute(
                    builder: (context) => const CreateChatScreen()),
              );
            },
          ),
        ],
      ),
      backgroundColor: kBackgroundColor,
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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

                return FutureBuilder<List<String>>(
                  future: Future.wait(chats.map((chat) async {
                    var participants = List<String>.from(chat['participants']);
                    var friendUid = participants
                        .firstWhere((uid) => uid != _auth.currentUser!.uid);
                    var friendUsername = await _getFriendUsername(friendUid);
                    return friendUsername;
                  })),
                  builder: (context, usernameSnapshot) {
                    if (!usernameSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var usernames = usernameSnapshot.data!;
                    var filteredChats = _searchQuery.isNotEmpty
                        ? chats.where((chat) {
                            int index = chats.indexOf(chat);
                            return index < usernames.length &&
                                usernames[index]
                                    .toLowerCase()
                                    .contains(_searchQuery);
                          }).toList()
                        : chats;

                    return ListView.separated(
                      itemCount: filteredChats.length,
                      separatorBuilder: (context, index) => const Divider(
                        color: Colors.grey,
                        thickness: 0.5,
                        indent: 16,
                        endIndent: 16,
                      ),
                      itemBuilder: (context, index) {
                        var chat = filteredChats[index];
                        var participants =
                            List<String>.from(chat['participants']);
                        var friendUid = participants.firstWhere(
                            (uid) => uid != _auth.currentUser!.uid,
                            orElse: () => participants[0]); // Fallback safety

                        // Safety check to ensure index is within bounds
                        String friendUsername = index < usernames.length
                            ? usernames[index]
                            : 'Unknown';

                        return FutureBuilder<DocumentSnapshot>(
                          future: _firestore
                              .collection('users')
                              .doc(friendUid)
                              .get(),
                          builder: (context, friendSnapshot) {
                            if (!friendSnapshot.hasData) {
                              return const ListTile();
                            }

                            var friendData = friendSnapshot.data!;
                            var friendImageUrl = friendData['imageUrl'];
                            var lastMessage =
                                chat['lastMessage']?['content'] ?? 'No message';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    friendImageUrl != null &&
                                            friendImageUrl.isNotEmpty
                                        ? NetworkImage(friendImageUrl)
                                        : const AssetImage(
                                                'assets/icons/ShuffleLogo.jpeg')
                                            as ImageProvider,
                              ),
                              title: Text(
                                friendUsername,
                                style: const TextStyle(
                                  color: Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                lastMessage,
                                style: const TextStyle(
                                  color: Colors.black54,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ChatScreen(friendUid: friendUid),
                                  ),
                                );
                              },
                            );
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
}