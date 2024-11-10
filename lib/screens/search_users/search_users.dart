import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/widgets/invite_button.dart';

import 'package:my_flutter_app/services/invite_service.dart';


class SearchUsers extends StatefulWidget {
  const SearchUsers({super.key});

  @override
  _SearchUsersState createState() => _SearchUsersState();
}

class _SearchUsersState extends State<SearchUsers> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<DocumentSnapshot> _users = [];
  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  void _searchUsers(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch the current user's document to check for the 'blockedBy' field
      DocumentSnapshot currentUserDoc =
          await _firestore.collection('users').doc(_currentUser?.uid).get();

      // Check if the 'blockedBy' field exists for the current user
      List blockedBy = currentUserDoc.data().toString().contains('blockedBy')
          ? (currentUserDoc['blockedBy'] ?? [])
          : [];

      QuerySnapshot result = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      // Filter out the users that the current user has blocked or has been blocked by
      List<DocumentSnapshot> filteredUsers = [];
      for (var user in result.docs) {
        // Exclude users that have blocked the current user
        if (!blockedBy.contains(user.id)) {
          filteredUsers.add(user);
        }
      }

      setState(() {
        _users = filteredUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching users: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Users',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kBackgroundColor,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Invite Friends',
              onPressed: () => InviteService.sendInvitations(context),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
              onChanged: _searchUsers,
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red))
            else if (_users.isEmpty)
              const Text('No users found.', style: TextStyle(color: Colors.black))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    var user = _users[index];
                    var username = user['username'] ?? '';
                    var fullName = user['fullName'] ?? '';
                    var imageUrl = user.data().toString().contains('imageUrl') ? user['imageUrl'] : null;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                            ? NetworkImage(imageUrl)
                            : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                      ),
                      title: Text(fullName),
                      subtitle: Text('@$username'),
                      onTap: () {
                        if (user.id == _currentUser?.uid) {
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
                              builder: (context) => ViewUserProfile(uid: user.id),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
