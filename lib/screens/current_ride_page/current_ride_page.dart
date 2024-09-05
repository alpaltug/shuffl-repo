import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';


class CurrentRidePage extends StatefulWidget {
  final String rideId;
  const CurrentRidePage({super.key, required this.rideId});

  @override
  _CurrentRidePageState createState() => _CurrentRidePageState();
}

class _CurrentRidePageState extends State<CurrentRidePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isComplete = false;
  bool isUserInRide = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Ride'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('rides').doc(widget.rideId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'), // Add your logo path here
            );
          }

          // Check if the document exists
          if (!snapshot.data!.exists) {
            // Navigate back to the homepage since the ride has been deleted
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            });
            return const Center(child: Text('This ride no longer exists.'));
          }

          var rideData = snapshot.data!;
          List<String> participants = List<String>.from(rideData['participants']);
          User? currentUser = _auth.currentUser;

          isComplete = rideData['isComplete'] ?? false;
          isUserInRide = participants.contains(currentUser?.uid);

          return Column(
            children: [
              ListTile(
                title: const Text('Pickup Location'),
                subtitle: Text(rideData['pickupLocations'][0] ?? 'Not calculated yet'), // Adjust if needed
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    String participantId = participants[index];
                    return FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(participantId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const ListTile(title: Text('Loading...'));
                        }
                        var participantData = userSnapshot.data!;
                        return ListTile(
                          title: Text(participantData['username']),
                          subtitle: Text(participantData['fullName']),
                          onTap: () {
                            if (participantId == _auth.currentUser?.uid) {
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
                                  builder: (context) => ViewUserProfile(uid: participantId),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              if (!isComplete)
                isUserInRide
                    ? ElevatedButton(
                        onPressed: _leaveRide,
                        child: const Text('Leave Group'),
                      )
                    : ElevatedButton(
                        onPressed: _joinRide,
                        child: const Text('Join Group'),
                      ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _joinRide() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    DocumentReference rideDocRef = _firestore.collection('rides').doc(widget.rideId);

    rideDocRef.update({
      'participants': FieldValue.arrayUnion([currentUser.uid]),
    });

    setState(() {
      isUserInRide = true;
    });
  }

  Future<void> _leaveRide() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentReference rideDocRef = _firestore.collection('rides').doc(widget.rideId);

    await rideDocRef.update({
      'participants': FieldValue.arrayRemove([user.uid]),
    });

    DocumentSnapshot rideSnapshot = await rideDocRef.get();
    if (rideSnapshot.exists) {
      List<String> participants = List<String>.from(rideSnapshot['participants']);
      if (participants.isEmpty) {
        // If no participants remain, delete the ride document
        await rideDocRef.delete();
      }
    }
    // Navigate back to the homepage
    Navigator.push(context,MaterialPageRoute(builder: (context) => HomePage(),
    ),
    );
  }
}