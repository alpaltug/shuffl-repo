import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/search_users/search_users.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';


class UserFriends extends StatefulWidget {
  const UserFriends({super.key});

  @override
  _UserFriendsState createState() => _UserFriendsState();
}

class _UserFriendsState extends State<UserFriends> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  Future<List<DocumentSnapshot>> _getFriends() async {
    if (_currentUser == null) return [];
    DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(_currentUser!.uid).get();
    List friends = (userSnapshot.data() as Map?)?.containsKey('friends') == true ? List.from(userSnapshot['friends']) : [];
    if (friends.isEmpty) return [];
    return _firestore.collection('users').where(FieldPath.documentId, whereIn: friends).get().then((query) => query.docs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Friends',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: kBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchUsers()),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _getFriends(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'), // Add your logo path here
            );
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading friends'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('You have no friends...'));
          }

          var friends = snapshot.data!;

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              var friend = friends[index];
              return ListTile(
                title: Text(friend['username']),
                subtitle: Text(friend['fullName']),
                leading: CircleAvatar(
                  backgroundImage: friend['imageUrl'] != null && friend['imageUrl'].isNotEmpty
                      ? NetworkImage(friend['imageUrl'])
                      : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ViewUserProfile(uid: friend.id)),
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