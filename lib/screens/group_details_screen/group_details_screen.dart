import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/add_user_to_group_screen/add_user_to_group_screen.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';

class GroupDetailScreen extends StatefulWidget {
  final String chatId;
  final bool isReferralGroup;

  GroupDetailScreen({
    required this.chatId,
    required this.isReferralGroup,
  });

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<DocumentSnapshot> _participants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      DocumentSnapshot chatDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chats')
          .doc(widget.chatId)
          .get();

      if (!chatDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat does not exist.')),
        );
        return;
      }

      List<String> participantUids = List<String>.from(chatDoc['participants'] ?? []);

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
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading participants: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading group details: $e')),
      );
    }
  }

  Future<void> _leaveGroup() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      DocumentSnapshot userChatDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chats')
          .doc(widget.chatId)
          .get();

      if (!userChatDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat does not exist.')),
        );
        return;
      }

      List<String> participants = List<String>.from(userChatDoc['participants'] ?? []);

      participants.remove(currentUser.uid);

      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      String displayName = userDoc['username'] ?? 'A user';

      for (String uid in participants) {
        DocumentReference chatRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('chats')
            .doc(widget.chatId);

        DocumentSnapshot chatSnapshot = await chatRef.get();
        if (chatSnapshot.exists) {
          await chatRef.update({
            'participants': participants,
            'lastMessage': {
              'content': '@$displayName has left the group',
              'timestamp': FieldValue.serverTimestamp(),
            },
          });

          await chatRef.collection('messages').add({
            'content': '@$displayName has left the group',
            'timestamp': FieldValue.serverTimestamp(),
            'senderId': 'system',
          });
        }
      }

      if (widget.isReferralGroup) {
        QuerySnapshot referralQuery = await _firestore
            .collection('referral_codes')
            .where('group_chat_id', isEqualTo: widget.chatId)
            .get();

        if (referralQuery.docs.isNotEmpty) {
          DocumentSnapshot referralDoc = referralQuery.docs.first;
          List<dynamic> referralParticipants = referralDoc['participants'] ?? [];

          referralParticipants.remove(currentUser.uid);

          await referralDoc.reference.update({
            'participants': referralParticipants,
          });

          if (referralParticipants.isEmpty) {
            await referralDoc.reference.delete();
          }
        } else {
          print('No referral_codes document found for chatId: ${widget.chatId}');
        }
      }

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chats')
          .doc(widget.chatId)
          .delete();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomePage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error leaving group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error leaving group: $e')),
      );
    }
  }

  ImageProvider<Object> _getProfileImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return const AssetImage('assets/icons/ShuffleLogo.jpeg');
    }
    return NetworkImage(imageUrl);
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
        title: const Text(
          'Group Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          if (!widget.isReferralGroup)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddUsersToGroupScreen(
                      chatId: widget.chatId,
                      currentParticipants: _participants,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _participants.isEmpty
                ? const Center(child: Text('No participants found.'))
                : ListView.builder(
                    itemCount: _participants.length,
                    itemBuilder: (context, index) {
                      var participant = _participants[index];
                      var imageUrl = participant['imageUrl'] ?? '';
                      var username = participant['username'] ?? 'User';
                      var uid = participant.id;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: _getProfileImage(imageUrl),
                        ),
                        title: Text(
                          username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onTap: () {
                          if (uid == _auth.currentUser?.uid) {
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
                                builder: (context) => ViewUserProfile(uid: uid),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: _leaveGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size(double.infinity, 50), 
              ),
              child: const Text(
                'Leave Group',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}