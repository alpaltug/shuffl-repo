import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/waiting_page/waiting_page.dart';
import 'package:my_flutter_app/screens/active_rides_page/active_rides_page.dart';
import 'package:my_flutter_app/widgets.dart';
import 'package:my_flutter_app/constants.dart'; // Ensure this import for constants

class UserRidesPage extends StatefulWidget {
  const UserRidesPage({super.key});

  @override
  _UserRidesPageState createState() => _UserRidesPageState();
}

class _UserRidesPageState extends State<UserRidesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
  }

  Future<List<String>> _getUsernamesFromUIDs(List<String> uids) async {
    List<String> usernames = [];
    for (String uid in uids) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      String username = userDoc['username'] ?? 'Unknown';
      usernames.add(username);
    }
    return usernames;
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    if (user == null) {
      return const Center(child: Text('Please log in to view your rides.'));
    }

    return Scaffold(
      appBar: const LogolessAppBar(
        title: 'My Rides',
        automaticallyImplyLeading: true, // Keep necessary buttons like back or search
      ),
      backgroundColor: kBackgroundColor, // Use the consistent background color
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('rides')
                  .where('participants', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final waitingRoomRides = snapshot.data!.docs;

                if (waitingRoomRides.isEmpty) {
                  return const Center(
                    child: Text(
                      'You have no rides in the waiting room.',
                      style: TextStyle(color: Colors.black), // Text color set to black
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text(
                        'Waiting Room',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black, // Text color set to black
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: waitingRoomRides.length,
                        itemBuilder: (context, index) {
                          var ride = waitingRoomRides[index];

                          return FutureBuilder<List<String>>(
                            future: _getUsernamesFromUIDs(List<String>.from(ride['participants'])),
                            builder: (context, usernamesSnapshot) {
                              if (!usernamesSnapshot.hasData) {
                                return const ListTile(
                                  title: Text('Loading...', style: TextStyle(color: Colors.black)), // Text color set to black
                                );
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                                color: Colors.grey[200],
                                child: ListTile(
                                  title: Text(
                                    'Pickup: ${ride['pickupLocations'][_userId] ?? 'Unknown'}',
                                    style: const TextStyle(color: Colors.black), // Text color set to black
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dropoff: ${ride['dropoffLocations'][_userId] ?? 'Unknown'}',
                                        style: const TextStyle(color: Colors.black), // Text color set to black
                                      ),
                                      Text(
                                        'Time: ${ride['timeOfRide'].toDate()}',
                                        style: const TextStyle(color: Colors.black), // Text color set to black
                                      ),
                                      Text(
                                        'Participants: ${usernamesSnapshot.data!.join(", ")}',
                                        style: const TextStyle(color: Colors.black), // Text color set to black
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => WaitingPage(rideId: ride.id)),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(color: Colors.black, thickness: 2),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('active_rides')
                  .where('participants', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final activeRides = snapshot.data!.docs;

                if (activeRides.isEmpty) {
                  return const Center(
                    child: Text(
                      'You have no active rides.',
                      style: TextStyle(color: Colors.black), // Text color set to black
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text(
                        'Rides',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black, // Text color set to black
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: activeRides.length,
                        itemBuilder: (context, index) {
                          var ride = activeRides[index];
                          DateTime rideTime = (ride['timeOfRide'] as Timestamp).toDate();
                          bool isPast = rideTime.isBefore(DateTime.now());

                          return FutureBuilder<List<String>>(
                            future: _getUsernamesFromUIDs(List<String>.from(ride['participants'])),
                            builder: (context, usernamesSnapshot) {
                              if (!usernamesSnapshot.hasData) {
                                return const ListTile(
                                  title: Text('Loading...', style: TextStyle(color: Colors.black)), // Text color set to black
                                );
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                                color: isPast ? Colors.red[50] : Colors.blue[50],
                                child: ListTile(
                                  title: Text(
                                    'Pickup: ${ride['pickupLocations'][_userId] ?? 'Unknown'}',
                                    style: const TextStyle(color: Colors.black), // Text color set to black
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dropoff: ${ride['dropoffLocations'][_userId] ?? 'Unknown'}',
                                        style: const TextStyle(color: Colors.black), // Text color set to black
                                      ),
                                      Text(
                                        'Time: ${rideTime.toString()}',
                                        style: const TextStyle(color: Colors.black), // Text color set to black
                                      ),
                                      Text(
                                        'Participants: ${usernamesSnapshot.data!.join(", ")}',
                                        style: const TextStyle(color: Colors.black), // Text color set to black
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => ActiveRidesPage(rideId: ride.id)),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
