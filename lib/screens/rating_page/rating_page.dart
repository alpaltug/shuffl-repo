import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';

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
        _ratings[participantId] = 0.0;
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
      appBar: AppBar(
        title: Text('Rate Participants'),
      ),
      body: ListView.builder(
        itemCount: _ratings.length,
        itemBuilder: (context, index) {
          String participantId = _ratings.keys.elementAt(index);
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(participantId).get(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;
                String username = userData['username'];
                String imageUrl = userData['imageUrl'];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                  ),
                  title: Text(username),
                  subtitle: StarRating(
                    rating: _ratings[participantId]!,
                    onRatingChanged: (rating) => _updateRating(participantId, rating),
                  ),
                );
              } else {
                return ListTile(
                  title: Text('Loading...'),
                );
              }
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitRatings,
        child: Icon(Icons.check),
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
               index < rating ? Icons.star : Icons.star_border,
               color: Colors.amber,
             ),
             onPressed: () => onRatingChanged(index + 1.0),
           );
         }),
       );
     }
   }