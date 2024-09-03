import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/screens/friend_chat_screen/friend_chat_screen.dart';

class ViewUserProfile extends StatefulWidget {
  final String uid;
  const ViewUserProfile({super.key, required this.uid});

  @override
  _ViewUserProfileState createState() => _ViewUserProfileState();
}

class _ViewUserProfileState extends State<ViewUserProfile> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  DocumentSnapshot? userProfile;
  bool isLoading = true;
  String? _displayName;
  String? _username;
  String? _description;
  String? _imageUrl;
  double _averageRating = 0.0;
  int _numRides = 0;
  bool isFriendRequestSent = false;
  bool isAlreadyFriend = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _checkFriendStatus();
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
          _averageRating = userProfile!['rating'] ?? 0.0;
          _numRides = userProfile!['numRides'] ?? 0;
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

  void _checkFriendStatus() async {
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      DocumentSnapshot currentUserSnapshot = await _firestore.collection('users').doc(currentUser.uid).get();
      List friends = currentUserSnapshot.data().toString().contains('friends')
          ? List.from(currentUserSnapshot['friends'])
          : [];
      if (friends.contains(widget.uid)) {
        setState(() {
          isAlreadyFriend = true;
        });
        return;
      }

      QuerySnapshot sentRequests = await _firestore
          .collection('users')
          .doc(widget.uid)
          .collection('notifications')
          .where('fromUid', isEqualTo: currentUser.uid)
          .where('type', isEqualTo: 'friend_request')
          .get();
      if (sentRequests.docs.isNotEmpty) {
        setState(() {
          isFriendRequestSent = true;
        });
      }
    }
  }

  void _addFriend() async {
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      await _firestoreService.sendFriendRequest(currentUser.uid, widget.uid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent')),
      );
      setState(() {
        isFriendRequestSent = true;
      });
    }
  }

  Future<void> _unfriend() async {
    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      await _firestore.collection('users').doc(currentUser.uid).update({
        'friends': FieldValue.arrayRemove([widget.uid])
      });
      await _firestore.collection('users').doc(widget.uid).update({
        'friends': FieldValue.arrayRemove([currentUser.uid])
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unfriended successfully')),
      );

      setState(() {
        isAlreadyFriend = false;
      });
    }
  }

  void _showUnfriendConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unfriend Confirmation', style: TextStyle(color: Colors.black)),
          content: const Text('Are you sure you want to remove this friend?', style: TextStyle(color: Colors.black)),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () {
                Navigator.of(context).pop();
                _unfriend();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(friendUid: widget.uid),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
  final TextEditingController _descriptionController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: kBackgroundColor,
            borderRadius: BorderRadius.circular(15),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    labelStyle: const TextStyle(color: Colors.black),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () async {
                      User? currentUser = _auth.currentUser;
                      if (currentUser != null) {
                        Map<String, dynamic> reportData = {
                          'description': _descriptionController.text,
                          'reportedUsername': _username, // This is now correct - it's the username of the user being viewed/reported
                          'timestamp': FieldValue.serverTimestamp(),
                          'userId': currentUser.uid,
                        };

                        try {
                          await _firestore
                              .collection('reports')
                              .doc('user')
                              .collection('entries')
                              .add(reportData);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('User reported successfully.')),
                          );

                          Navigator.pop(context);
                        } catch (e) {
                          print('Error reporting user: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to submit report. Please try again.')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text(
                      'Report',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: kBackgroundColor,
        iconTheme: const IconThemeData(color: Colors.black),
        automaticallyImplyLeading: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(defaultPadding),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star, color: Colors.yellow),
                              const SizedBox(width: 5),
                              Text(
                                '${_averageRating.toStringAsFixed(2)} | $_numRides rides',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '@$_username',
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.green,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _description ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          if (isAlreadyFriend)
                            Column(
                              children: [
                                GreenActionButton(
                                  text: 'Message',
                                  color: kBackgroundColor,
                                  onPressed: _navigateToChat,
                                ),
                                const SizedBox(height: 10),
                                GreenActionButton(
                                  text: 'Unfriend',
                                  color: Colors.grey,
                                  onPressed: _showUnfriendConfirmationDialog,
                                ),
                              ],
                            )
                          else
                            GreenActionButton(
                              text: isFriendRequestSent ? 'Request Sent' : 'Add Friend',
                              onPressed: () {
                                if (!isFriendRequestSent) {
                                  _addFriend();
                                }
                              },
                            ),
                          const SizedBox(height: 10),
                          GreenActionButton(
                            text: 'Report User',
                            color: Colors.red,
                            onPressed: () => _showReportDialog(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}