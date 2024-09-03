import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';  // Make sure this import is included
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';  // Import UserProfile
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';  // Import ViewUserProfile

class ParticipantListWidget extends StatelessWidget {
  final List<DocumentSnapshot> users;

  const ParticipantListWidget({
    Key? key,
    required this.users,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        var user = users[index];
        var username = user['username'] ?? '';
        var fullName = user['fullName'] ?? '';
        var imageUrl = user.data().toString().contains('imageUrl') ? user['imageUrl'] : null;

        return Card(
          color: Colors.green[50],
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          child: ListTile(
            leading: CircleAvatar(
              radius: 30,
              backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
            ),
            title: Text(
              fullName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            subtitle: Text(
              '@$username',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            onTap: () {
              if (user.id == FirebaseAuth.instance.currentUser?.uid) { 
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
          ),
        );
      },
    );
  }
}
