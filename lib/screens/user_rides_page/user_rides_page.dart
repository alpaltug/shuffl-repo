import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRidesPage extends StatefulWidget {
  const UserRidesPage({super.key});

  @override
  _UserRidesPageState createState() => _UserRidesPageState();
}

class _UserRidesPageState extends State<UserRidesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text('Please log in to view your rides.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rides'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('rides').where('participants', arrayContains: user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rides = snapshot.data!.docs;

          if (rides.isEmpty) {
            return const Center(child: Text('You have no ride history.'));
          }

          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              var ride = rides[index];

              return ListTile(
                title: Text('Pickup: ${ride['pickupLocation']}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dropoff: ${ride['dropoffLocations'].join(", ")}'),
                    Text('Time: ${ride['timeOfRide'].toDate()}'),
                    Text('Participants: ${List<String>.from(ride['participants']).join(", ")}'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
