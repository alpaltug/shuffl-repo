import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:intl/intl.dart';
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
  DateTime? _rideEndTime;

  @override
  void initState() {
    super.initState();
    _loadRideEndTime();
    _initializeRatings();
  }

  Future<void> _loadRideEndTime() async {
    DocumentSnapshot rideDoc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .get();

    if (rideDoc.exists) {
      Timestamp endTimeStamp = rideDoc['timestamp']; // Assuming 'timestamp' is the ride end time
      _rideEndTime = endTimeStamp.toDate();
    }
  }

  void _initializeRatings() {
    String currentUserId = _auth.currentUser!.uid;
    for (String participantId in widget.participants) {
      if (participantId != currentUserId) {
        _ratings[participantId] = 5.0; // Default to 5 stars
      }
    }
  }

  void _updateRating(String participantId, double rating) {
    setState(() {
      _ratings[participantId] = rating;
    });
  }

  Future<void> _submitRatings() async {
    if (_rideEndTime != null && DateTime.now().isAfter(_rideEndTime!.add(Duration(days: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can no longer submit ratings for this ride.')),
      );
      return;
    }

    for (String participantId in _ratings.keys) {
      double rating = _ratings[participantId]!;
      await _firestoreService.updateUserRating(participantId, rating);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  bool _canRate() {
    if (_rideEndTime == null) return true;
    return DateTime.now().isBefore(_rideEndTime!.add(Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor, 
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        title: const Text(
          'Rate Participants',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rideEndTime != null
                ? Text(
                    'Ride ended on: ${DateFormat.yMMMd().format(_rideEndTime!)}',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  )
                : Container(),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
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
                      String username = userData['username'] ?? 'Unknown User';
                      String? imageUrl = userData['imageUrl'] as String?;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            radius: 30,
                            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                                ? NetworkImage(imageUrl)
                                : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                          ),
                          title: Text(username, style: const TextStyle(color: Colors.black)),
                          subtitle: StarRating(
                            rating: _ratings[participantId]!,
                            onRatingChanged: (rating) => _canRate() ? _updateRating(participantId, rating) : null,
                            enabled: _canRate(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _canRate()
          ? FloatingActionButton(
              backgroundColor: Colors.black,
              onPressed: _submitRatings,
              child: const Icon(Icons.check, color: Colors.white),
            )
          : null,
    );
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  final Function(double) onRatingChanged;
  final bool enabled;

  const StarRating({required this.rating, required this.onRatingChanged, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: enabled ? Colors.yellow : Colors.grey,
          ),
          onPressed: enabled ? () => onRatingChanged(index + 1.0) : null,
        );
      }),
    );
  }
}
