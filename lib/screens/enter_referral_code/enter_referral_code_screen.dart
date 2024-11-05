import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/constants.dart';

class EnterReferralCodeScreen extends StatefulWidget {
  const EnterReferralCodeScreen({Key? key}) : super(key: key);

  @override
  _EnterReferralCodeScreenState createState() => _EnterReferralCodeScreenState();
}

class _EnterReferralCodeScreenState extends State<EnterReferralCodeScreen> {
  final TextEditingController _referralCodeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submitReferralCode() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    String referralCode = _referralCodeController.text.trim();
    if (referralCode.isNotEmpty) {
      DocumentSnapshot doc = await _firestore
          .collection('referral_codes')
          .doc(referralCode)
          .get();

      if (doc.exists) {
        String orgName = doc['org_name'] ?? 'Unknown';
        User? user = _auth.currentUser;

        if (user != null) {
          try {
            // Fetch the current user's display name
            DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
            String displayName = userDoc['username'] ?? 'A user';

            List<dynamic> participants = [];
            var data = doc.data() as Map<String, dynamic>;
            if (data.containsKey('participants')) {
              participants = data['participants'];
            }

            if (participants.contains(user.uid)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('You are already a member of this organization/club.'),
                ),
              );
              setState(() {
                _isSubmitting = false;
              });
            } else {

              await _firestore
                  .collection('referral_codes')
                  .doc(referralCode)
                  .set({
                'participants': FieldValue.arrayUnion([user.uid]),
              }, SetOptions(merge: true));

              await _firestore.collection('users').doc(user.uid).set({
                'tags': FieldValue.arrayUnion([orgName]),
              }, SetOptions(merge: true));

              DocumentSnapshot updatedDoc = await _firestore
                  .collection('referral_codes')
                  .doc(referralCode)
                  .get();
              List<dynamic> updatedMembers = updatedDoc['participants'] ?? [];

              Map<String, dynamic>? updatedData = updatedDoc.data() as Map<String, dynamic>?;
              String? groupChatId = updatedData != null && updatedData.containsKey('group_chat_id')
                  ? updatedData['group_chat_id']
                  : null;

              if (updatedMembers.length >= 2) {
                if (groupChatId == null) {
                  String newGroupChatId = _firestore.collection('group_chats').doc().id;

                  await _firestore
                      .collection('referral_codes')
                      .doc(referralCode)
                      .set({
                    'group_chat_id': newGroupChatId,
                  }, SetOptions(merge: true));

                  Map<String, dynamic> chatData = {
                    'participants': updatedMembers,
                    'isGroupChat': true,
                    'groupTitle': orgName,
                    'isReferralGroup': true,
                    'lastMessage': {
                      'content': '@system Group chat created',
                      'timestamp': FieldValue.serverTimestamp(),
                    },
                  };

                  for (String memberId in updatedMembers) {
                    await _firestore
                        .collection('users')
                        .doc(memberId)
                        .collection('chats')
                        .doc(newGroupChatId)
                        .set(chatData);

                    await _firestore
                        .collection('users')
                        .doc(memberId)
                        .collection('chats')
                        .doc(newGroupChatId)
                        .collection('messages')
                        .add({
                      'senderId': 'system',
                      'content': '@system Group chat created',
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  }
                } else {
                  for (String memberId in updatedMembers) {
                    DocumentReference chatDocRef = _firestore
                        .collection('users')
                        .doc(memberId)
                        .collection('chats')
                        .doc(groupChatId);

                    if (memberId == user.uid) {
                      Map<String, dynamic> chatData = {
                        'participants': updatedMembers,
                        'isGroupChat': true,
                        'groupTitle': orgName,
                        'isReferralGroup': true,
                        'lastMessage': {
                          'content': '@system Welcome to the group chat',
                          'timestamp': FieldValue.serverTimestamp(),
                        },
                      };
                      await chatDocRef.set(chatData);

                      await _firestore
                          .collection('users')
                          .doc(memberId)
                          .collection('chats')
                          .doc(groupChatId)
                          .collection('messages')
                          .add({
                        'senderId': 'system',
                        'content': '@system Welcome to the group chat',
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await chatDocRef.update({
                        'participants': updatedMembers,
                      });
                    }
                  }

                  String systemMessageContent =
                      '@$displayName has joined the group';

                  for (String memberId in updatedMembers) {
                    await _firestore
                        .collection('users')
                        .doc(memberId)
                        .collection('chats')
                        .doc(groupChatId)
                        .collection('messages')
                        .add({
                      'senderId': 'system',
                      'content': systemMessageContent,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    await _firestore
                        .collection('users')
                        .doc(memberId)
                        .collection('chats')
                        .doc(groupChatId)
                        .update({
                      'lastMessage': {
                        'content': systemMessageContent,
                        'timestamp': FieldValue.serverTimestamp(),
                      },
                    });
                  }
                }
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Referral code accepted! You have been tagged with $orgName.'),
                ),
              );
              Navigator.pop(context);
            }
          } catch (e) {
            setState(() {
              _errorMessage = 'An error occurred while updating your profile.';
              _isSubmitting = false;
            });
          }
        } else {
          setState(() {
            _errorMessage = 'Invalid referral code.';
            _isSubmitting = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid referral code.';
          _isSubmitting = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Please enter a referral code.';
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _referralCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Enter Referral Code',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kBackgroundColor,
      ),
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _referralCodeController,
                decoration: const InputDecoration(
                  labelText: 'Referral Code',
                  labelStyle: TextStyle(color: Colors.black),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReferralCode,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit', style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}