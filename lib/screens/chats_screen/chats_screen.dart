import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/friend_chat_screen/friend_chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  _ChatsScreenState createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: Colors.yellow,
      ),
      body: StreamBuilder<QuerySnapshot>(
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
              var friendUid = participants.firstWhere((uid) => uid != _auth.currentUser!.uid);

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(friendUid).get(),
                builder: (context, friendSnapshot) {
                  if (!friendSnapshot.hasData) {
                    return const ListTile();
                  }

                  var friendData = friendSnapshot.data!;
                  var friendUsername = friendData['username'];
                  var friendImageUrl = friendData['imageUrl'];
                  var lastMessage = chat['lastMessage']?['content'] ?? 'No message';

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: friendImageUrl != null && friendImageUrl.isNotEmpty
                          ? NetworkImage(friendImageUrl)
                          : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                    ),
                    title: Text(friendUsername),
                    subtitle: Text(lastMessage),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(friendUid: friendUid),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}