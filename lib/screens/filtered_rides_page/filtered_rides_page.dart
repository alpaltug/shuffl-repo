import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class FilteredRidesPage extends StatefulWidget {
  const FilteredRidesPage({super.key});

  @override
  _FilteredRidesPageState createState() => _FilteredRidesPageState();
}

class _FilteredRidesPageState extends State<FilteredRidesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rides'),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _fetchFilteredRides(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rides = snapshot.data!;

          if (rides.isEmpty) {
            return const Center(child: Text('No rides available that match your preferences.'));
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
                onTap: () {
                  _joinRide(ride.id, List<String>.from(ride['participants']));
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<DocumentSnapshot>> _fetchFilteredRides() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    DateTime now = DateTime.now();
    QuerySnapshot snapshot = await _firestore
        .collection('rides')
        .where('timeOfRide', isGreaterThan: now)
        .orderBy('timeOfRide')
        .get();

    List<DocumentSnapshot> filteredRides = [];

    for (var ride in snapshot.docs) {
      if (await _validatePreferences(ride)) {
        filteredRides.add(ride);
      }
    }

    // Delete rides older than 24 hours
    for (var ride in snapshot.docs) {
      DateTime timeOfRide = ride['timeOfRide'].toDate();
      if (timeOfRide.isBefore(now.subtract(Duration(hours: 24)))) {
        await ride.reference.delete();
      }
    }

    // Return the filtered rides
    return filteredRides;
  }

  Future<bool> _validatePreferences(DocumentSnapshot ride) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return false;

    // Fetch current user's preferences
    DocumentSnapshot currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    Map<String, dynamic> currentUserPreferences = currentUserDoc['preferences'];

    // Check preferences of all participants
    List<String> participants = List<String>.from(ride['participants']);
    for (String participantId in participants) {
      if (participantId == currentUser.uid) continue;

      DocumentSnapshot participantDoc = await _firestore.collection('users').doc(participantId).get();
      Map<String, dynamic> participantPreferences = participantDoc['preferences'];

      if (!_doesUserMatchPreferences(currentUserPreferences, participantPreferences) ||
          !_doesUserMatchPreferences(participantPreferences, currentUserPreferences)) {
        return false;
      }
    }
    return true;
  }

  bool _doesUserMatchPreferences(Map<String, dynamic> userPrefs, Map<String, dynamic> targetPrefs) {
    // Age Range Matching
    int userMinAge = userPrefs['ageRange']['min'];
    int userMaxAge = userPrefs['ageRange']['max'];
    int targetMinAge = targetPrefs['ageRange']['min'];
    int targetMaxAge = targetPrefs['ageRange']['max'];

    if (userMinAge > targetMaxAge || userMaxAge < targetMinAge) {
      return false;
    }

    // Car Capacity Matching
    int userMinCapacity = userPrefs['minCarCapacity'];
    int userMaxCapacity = userPrefs['maxCarCapacity'];
    int targetMinCapacity = targetPrefs['minCarCapacity'];
    int targetMaxCapacity = targetPrefs['maxCarCapacity'];

    if (userMinCapacity > targetMaxCapacity || userMaxCapacity < targetMinCapacity) {
      return false;
    }

    // School Domain Matching (if the user has enabled this preference)
    if (userPrefs['schoolToggle'] && userPrefs['domain'] != targetPrefs['domain']) {
      return false;
    }

    // Gender Matching (if the user has enabled this preference)
    if (userPrefs['sameGenderToggle'] && userPrefs['sexAssignedAtBirth'] != targetPrefs['sexAssignedAtBirth']) {
      return false;
    }

    // Add any other preference checks here...

    // If all checks pass, return true
    return true;
  }


  Future<void> _joinRide(String rideId, List<String> participants) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    if (!participants.contains(user.uid)) {
      participants.add(user.uid);

      // Update ride with new participant and recalculate pickup location
      String newPickupLocation = await _calculateMidpointAddress(participants);

      await _firestore.collection('rides').doc(rideId).update({
        'participants': participants,
        'pickupLocation': newPickupLocation,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have joined the ride!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already part of this ride.')),
      );
    }
  }

  Future<String> _calculateMidpointAddress(List<String> participants) async {
    List<LatLng> locations = [];

    for (String uid in participants) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      var location = userDoc['location'];
      locations.add(LatLng(location['latitude'], location['longitude']));
    }

    double avgLat = locations.map((loc) => loc.latitude).reduce((a, b) => a + b) / locations.length;
    double avgLng = locations.map((loc) => loc.longitude).reduce((a, b) => a + b) / locations.length;

    LatLng midpoint = LatLng(avgLat, avgLng);

    // Convert midpoint LatLng to an address
    return await _getAddressFromLatLng(midpoint);
  }

  Future<String> _getAddressFromLatLng(LatLng position) async {
    List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isNotEmpty) {
      return '${placemarks.first.street}, ${placemarks.first.locality}, ${placemarks.first.administrativeArea}';
    }
    return 'Unknown location';
  }
}
