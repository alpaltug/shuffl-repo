import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({Key? key}) : super(key: key);

  @override
  _BlockedUsersScreenState createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> blockedUserIds = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      setState(() {
        blockedUserIds = List<String>.from(userDoc['blockedUsers'] ?? []);
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Blocked Users',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: kBackgroundColor,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : blockedUserIds.isEmpty
              ? const Center(child: Text(
                    'No blocked users',
                    style: TextStyle(
                      color: Colors.black, // Sets the text color to black
                    ),
                  ),)
              : ListView.builder(
                  itemCount: blockedUserIds.length,
                  itemBuilder: (context, index) {
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(blockedUserIds[index]).get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const ListTile(
                            title: Text('Loading...'),
                          );
                        }
                        if (snapshot.hasError) {
                          return ListTile(
                            title: Text('Error: ${snapshot.error}'),
                          );
                        }
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const ListTile(
                            title: Text('User not found'),
                          );
                        }
                        var userData = snapshot.data!.data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: AssetImage('assets/icons/ShuffleLogo.jpeg'),
                          ),
                          title: Text(
                            userData['fullName'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          subtitle: Text(
                            userData['username'] ?? '',
                            style: TextStyle(color: Colors.black),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewUserProfile(uid: blockedUserIds[index]),
                              ),
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