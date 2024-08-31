import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/waiting_page/waiting_page.dart';
import 'package:my_flutter_app/screens/active_rides_page/active_rides_page.dart';

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
      appBar: AppBar(
        title: const Text('My Rides'),
        backgroundColor: Colors.white,
      ),
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
                  return const Center(child: Text('You have no rides in the waiting room.'));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: const Text(
                        'Waiting Room',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
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
                                  title: Text('Loading...'),
                                );
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                                color: Colors.grey[200],
                                child: ListTile(
                                  title: Text(
                                    'Pickup: ${ride['pickupLocations'][_userId] ?? 'Unknown'}', // Get the current user's pickup location
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Dropoff: ${ride['dropoffLocations'][_userId] ?? 'Unknown'}'), // Get the current user's dropoff location
                                      Text('Time: ${ride['timeOfRide'].toDate()}'),
                                      Text('Participants: ${usernamesSnapshot.data!.join(", ")}'),
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
          Divider(color: Colors.black, thickness: 2),
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
                  return const Center(child: Text('You have no active rides.'));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: const Text(
                        'Rides',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
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
                                  title: Text('Loading...'),
                                );
                              }

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                                color: isPast ? Colors.red[50] : Colors.blue[50],
                                child: ListTile(
                                  title: Text(
                                    'Pickup: ${ride['pickupLocations'][_userId] ?? 'Unknown'}', // Get the current user's pickup location
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Dropoff: ${ride['dropoffLocations'][_userId] ?? 'Unknown'}'), // Get the current user's dropoff location
                                      Text('Time: ${rideTime.toString()}'),
                                      Text('Participants: ${usernamesSnapshot.data!.join(", ")}'),
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
