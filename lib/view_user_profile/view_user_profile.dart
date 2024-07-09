import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/widgets.dart'; // Make sure to import the widgets file where ShufflLogoAppBar is defined

class ViewUserProfile extends StatefulWidget {
  final String uid;
  const ViewUserProfile({super.key, required this.uid});

  @override
  _ViewUserProfileState createState() => _ViewUserProfileState();
}

class _ViewUserProfileState extends State<ViewUserProfile> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentSnapshot? userProfile;
  bool isLoading = true;
  String? _displayName;
  String? _username;
  String? _description;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    try {
      userProfile = await _firestore.collection('users').doc(widget.uid).get();
      if (userProfile != null) {
        setState(() {
          _displayName = userProfile!['fullName'] ?? '';
          _username = userProfile!['username'] ?? '';
          _description = userProfile!['description'] ?? '';
          _imageUrl = userProfile!.data().toString().contains('imageUrl') ? userProfile!['imageUrl'] : null;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user profile: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _addFriend() async {
    // Implement the logic for adding a friend here later hehe
    print('Add friend button clicked');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LogoAppBar(title: 'User Profile'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _imageUrl != null && _imageUrl!.isNotEmpty
                        ? NetworkImage(_imageUrl!)
                        : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _displayName ?? '',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '@$_username',
                    style: const TextStyle(fontSize: 20, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _description ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  GreenActionButton(
                    text: 'Add Friend',
                    onPressed: _addFriend,
                  ),
                ],
              ),
            ),
    );
  }
}