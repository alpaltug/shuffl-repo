import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/constants.dart'; // Make sure kBackgroundColor is defined in this file

class RatingPage extends StatefulWidget {
  final String rideId;
  final List<String> participants;

  const RatingPage({required this.rideId, required this.participants});

  @override
  _RatingPageState createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, double> _ratings = {};

  @override
  void initState() {
    super.initState();
    String currentUserId = _auth.currentUser!.uid;
    for (String participantId in widget.participants) {
      if (participantId != currentUserId) {
        // Initialize all ratings to 5 stars
        _ratings[participantId] = 5.0;
      }
    }
  }

  void _updateRating(String participantId, double rating) {
    setState(() {
      _ratings[participantId] = rating;
    });
  }

  Future<void> _submitRatings() async {
    for (String participantId in _ratings.keys) {
      double rating = _ratings[participantId]!;
      await _firestoreService.updateUserRating(participantId, rating);
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor, // Set the whole background color
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        title: const Text(
          'Rate Participants',
          style: TextStyle(
            color: Colors.white, // Set text color to white
            fontWeight: FontWeight.bold, // Make text bold
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: _ratings.length,
        itemBuilder: (context, index) {
          String participantId = _ratings.keys.elementAt(index);
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(participantId).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(title: Text('Loading...'));
              }

              if (snapshot.hasError) {
                return const ListTile(title: Text('Error loading user data.'));
              }

              if (!snapshot.hasData || snapshot.data!.data() == null) {
                return const ListTile(title: Text('User data not found.'));
              }

              Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;

              // Safely extract values with null checks
              String username = userData['username'] ?? 'Unknown User';
              String? imageUrl = userData['imageUrl'] as String?;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                      ? NetworkImage(imageUrl)
                      : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                ),
                title: Text(username, style: const TextStyle(color: Colors.white)), // Set username color to white
                subtitle: StarRating(
                  rating: _ratings[participantId]!,
                  onRatingChanged: (rating) => _updateRating(participantId, rating),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black, // Set the floating button color
        onPressed: _submitRatings,
        child: const Icon(Icons.check, color: Colors.white), // Set the icon color to white
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  final Function(double) onRatingChanged;

  const StarRating({required this.rating, required this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < rating ? Icons.star : Icons.star_border, // Fill stars based on rating
            color: Colors.black,
          ),
          onPressed: () => onRatingChanged(index + 1.0), // Update rating when a star is pressed
        );
      }),
    );
  }
}