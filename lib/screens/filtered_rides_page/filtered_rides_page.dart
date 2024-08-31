import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:my_flutter_app/screens/waiting_page/waiting_page.dart';

class FilteredRidesPage extends StatefulWidget {
  const FilteredRidesPage({super.key});

  @override
  _FilteredRidesPageState createState() => _FilteredRidesPageState();
}

class _FilteredRidesPageState extends State<FilteredRidesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Future<List<DocumentSnapshot>> _filteredRidesFuture;

  @override
  void initState() {
    super.initState();
    _filteredRidesFuture = _fetchFilteredRides();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rides'),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _filteredRidesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredRides = snapshot.data!;
          print('Number of filtered rides: ${filteredRides.length}');

          if (filteredRides.isEmpty) {
            return const Center(child: Text('No rides available that match your preferences.'));
          }

          return ListView.builder(
            itemCount: filteredRides.length,
            itemBuilder: (context, index) {
              var ride = filteredRides[index];

              return FutureBuilder<List<String>>(
                future: _getParticipantUsernames(List<String>.from(ride['participants'])),
                builder: (context, participantsSnapshot) {
                  if (!participantsSnapshot.hasData) {
                    return const ListTile(
                      title: Text('Loading...'),
                    );
                  }

                  final participantUsernames = participantsSnapshot.data!;
                  print('Participant usernames for ride $index: $participantUsernames');

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    color: Colors.grey[200],
                    child: ListTile(
                      title: Text(
                        'Pickup: ${ride['pickupLocations'].values.join(", ")}', // Update to handle map
                        style: const TextStyle(color: Colors.black),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dropoff: ${ride['dropoffLocations'].values.join(", ")}'), // Update to handle map
                          Text('Time: ${ride['timeOfRide'].toDate()}'),
                          Text('Participants: ${participantUsernames.join(", ")}'),
                        ],
                      ),
                      onTap: () {
                        _showRideDetailsModal(context, ride, participantUsernames);
                      },
                    ),
                  );
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
        .orderBy('timeOfRide')
        .get();

    DocumentSnapshot currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    Map<String, dynamic> currentUserData = currentUserDoc.data() as Map<String, dynamic>;

    List<DocumentSnapshot> filteredRides = [];

    for (var ride in snapshot.docs) {
      bool isComplete = ride['isComplete'] ?? false;
      if (!isComplete) {
        bool isValid = await _validatePreferences(ride, currentUserData);
        if (isValid) {
          filteredRides.add(ride);
        }
      }
    }

    for (var ride in snapshot.docs) {
      DateTime timeOfRide = ride['timeOfRide'].toDate();
      if (timeOfRide.isBefore(now.subtract(Duration(hours: 24)))) {
        await ride.reference.delete();
      }
    }

    return filteredRides;
  }

  Future<bool> _validatePreferences(DocumentSnapshot ride, Map<String, dynamic> currentUserData) async {
    List<String> participants = List<String>.from(ride['participants']);
    int currentGroupSize = participants.length;

    for (String participantId in participants) {
      DocumentSnapshot participantDoc = await _firestore.collection('users').doc(participantId).get();
      Map<String, dynamic> participantData = participantDoc.data() as Map<String, dynamic>;

      if (!_doesUserMatchPreferences(currentUserData, participantData, currentGroupSize) ||
          !_doesUserDataMatchPreferences(participantData, currentUserData, currentGroupSize)) {
        return false;
      }
    }
    return true;
  }

  bool _doesUserMatchPreferences(Map<String, dynamic> currentUserData, Map<String, dynamic> targetData, int currentGroupSize) {
    Map<String, dynamic> userPrefs = currentUserData['preferences'];

    int userMinAge = userPrefs['ageRange']['min'];
    int userMaxAge = userPrefs['ageRange']['max'];
    int targetAge = targetData['age'];

    if (targetAge < userMinAge || targetAge > userMaxAge) {
      return false;
    }

    // Validate car capacity
    int userMinCapacity = userPrefs['minCarCapacity'];
    int userMaxCapacity = userPrefs['maxCarCapacity'];

    if (currentGroupSize + 1 < userMinCapacity || currentGroupSize + 1 > userMaxCapacity) {
      return false;
    }

    // Other validations (school domain, gender)
    String? userDomain = currentUserData['domain'];
    String? targetDomain = targetData['domain'];

    if (userPrefs['schoolToggle'] == true && userDomain != targetDomain) {
      return false;
    }

    String? userGender = currentUserData['sexAssignedAtBirth'];
    String? targetGender = targetData['sexAssignedAtBirth'];

    if (userPrefs['sameGenderToggle'] == true && userGender != targetGender) {
      print('Gender validation failed: userGender $userGender, targetGender $targetGender');
      return false;
    }
    return true;
  }

  bool _doesUserDataMatchPreferences(Map<String, dynamic> participantData, Map<String, dynamic> currentUserData, int currentGroupSize) {
    Map<String, dynamic> participantPrefs = participantData['preferences'];

    int userAge = currentUserData['age'];
    int minAge = participantPrefs['ageRange']['min'];
    int maxAge = participantPrefs['ageRange']['max'];

    if (userAge < minAge || userAge > maxAge) {
      return false;
    }
    int participantMinCapacity = participantPrefs['minCarCapacity'];
    int participantMaxCapacity = participantPrefs['maxCarCapacity'];

    if (currentGroupSize + 1 < participantMinCapacity || currentGroupSize + 1 > participantMaxCapacity) {
      return false;
    }

    String? participantDomain = participantData['domain'];
    String? userDomain = currentUserData['domain'];

    if (participantPrefs['schoolToggle'] == true && participantDomain != userDomain) {
      return false;
    }

    String? participantGender = participantData['sexAssignedAtBirth'];
    String? userGender = currentUserData['sexAssignedAtBirth'];

    if (participantPrefs['sameGenderToggle'] == true && participantGender != userGender) {
      return false;
    }
    return true;
  }

  Future<void> _joinRide(String rideId, List<String> participants) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    if (!participants.contains(user.uid)) {
      participants.add(user.uid);

      await _firestore.collection('rides').doc(rideId).update({
        'participants': participants,
        'readyStatus.${user.uid}': false, // Initialize ready status as false for the new participant
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have joined the ride!')),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => WaitingPage(rideId: rideId)),
    );
  }

  Future<List<String>> _getParticipantUsernames(List<String> participantIds) async {
    List<String> usernames = [];
    for (String uid in participantIds) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        usernames.add(userDoc['username']);
      }
    }
    return usernames;
  }

  void _showRideDetailsModal(BuildContext context, DocumentSnapshot ride, List<String> participantUsernames) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ride Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 16),
              Text(
                'Time: ${ride['timeOfRide'].toDate()}',
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                'Pickup: ${ride['pickupLocations'].values.join(", ")}', // Update to handle map
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                'Dropoff: ${ride['dropoffLocations'].values.join(", ")}', // Update to handle map
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const Text(
                'Participants:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 8),
              ...participantUsernames.map((username) => Text(username, style: const TextStyle(color: Colors.black))).toList(),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _joinRide(ride.id, List<String>.from(ride['participants'])),
                child: const Text('Join Ride'),
              ),
            ],
          ),
        );
      },
    );
  }
}
