import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/waiting_page/waiting_page.dart';
import 'package:my_flutter_app/screens/active_rides_page/active_rides_page.dart';
import 'package:my_flutter_app/widgets/ride_card.dart';
import 'package:my_flutter_app/constants.dart';

class UserRidesPage extends StatefulWidget {
  const UserRidesPage({super.key});

  @override
  _UserRidesPageState createState() => _UserRidesPageState();
}

class _UserRidesPageState extends State<UserRidesPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Pending Rides"),
            Tab(text: "Active Rides"),
          ],
        ),
      ),
      backgroundColor: kBackgroundColor,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingRides(context, user.uid),
          _buildActiveRides(context, user.uid),
        ],
      ),
    );
  }

  Widget _buildRideCard(DocumentSnapshot ride, String userId) {
    return FutureBuilder<List<String>>(
      future: _getUsernamesFromUIDs(List<String>.from(ride['participants'])),
      builder: (context, usernamesSnapshot) {
        if (!usernamesSnapshot.hasData) {
          return const ListTile(
            title: Text('Loading...', style: TextStyle(color: Colors.black)),
          );
        }

        return GestureDetector(
          onTap: () {
            final targetPage = ride.reference.parent.id == 'rides'
                ? WaitingPage(rideId: ride.id)
                : ActiveRidesPage(rideId: ride.id);

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => targetPage),
            );
          },
          child: RideCard(
            ride: ride.data() as Map<String, dynamic>,
            participantUsernames: usernamesSnapshot.data!,
          ),
        );
      },
    );
  }

  Widget _buildPendingRides(BuildContext context, String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('rides')
          .where('participants', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRides = snapshot.data!.docs;

        // Separate today's rides and other rides
        List<DocumentSnapshot> todayRides = [];
        List<DocumentSnapshot> otherRides = [];

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        for (var ride in allRides) {
          DateTime rideTime = (ride['timeOfRide'] as Timestamp).toDate();
          if (rideTime.isAfter(today)) {
            todayRides.add(ride);
          } else {
            otherRides.add(ride);
          }
        }

        if (allRides.isEmpty) {
          return const Center(
            child: Text(
              'You have no rides in the waiting room.',
              style: TextStyle(color: Colors.black),
            ),
          );
        }

        return ListView(
          children: [
            if (todayRides.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(10.0),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              ...todayRides.map((ride) => _buildRideCard(ride, userId)),
            ],
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: Text(
                'Other Dates',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            ...otherRides.map((ride) => _buildRideCard(ride, userId)),
          ],
        );
      },
    );
  }

  Widget _buildActiveRides(BuildContext context, String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('active_rides')
          .where('participants', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allRides = snapshot.data!.docs;

        // Separate today's rides and other rides
        List<DocumentSnapshot> todayRides = [];
        List<DocumentSnapshot> otherRides = [];

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        for (var ride in allRides) {
          DateTime rideTime = (ride['timeOfRide'] as Timestamp).toDate();
          if (rideTime.isAfter(today)) {
            todayRides.add(ride);
          } else {
            otherRides.add(ride);
          }
        }

        if (allRides.isEmpty) {
          return const Center(
            child: Text(
              'You have no active rides.',
              style: TextStyle(color: Colors.black),
            ),
          );
        }

        return ListView(
          children: [
            if (todayRides.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(10.0),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              ...todayRides.map((ride) => _buildRideCard(ride, userId)),
            ],
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: Text(
                'Other Dates',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            ...otherRides.map((ride) => _buildRideCard(ride, userId)),
          ],
        );
      },
    );
  }
}
