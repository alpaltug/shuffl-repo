import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:my_flutter_app/screens/current_ride_page/current_ride_page.dart';

final google_maps_api_key = 'AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk';

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
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('rides')
            .orderBy('timeOfRide')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rides = snapshot.data!.docs;
          print('Number of filtered rides: ${rides.length}');

          if (rides.isEmpty) {
            return const Center(child: Text('No rides available that match your preferences.'));
          }

          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              var ride = rides[index];

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

                  return ListTile(
                    title: Text('Pickup: ${ride['pickupLocations'][0]}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dropoff: ${ride['dropoffLocations'].join(", ")}'),
                        Text('Time: ${ride['timeOfRide'].toDate()}'),
                        Text('Participants: ${participantUsernames.join(", ")}'),
                      ],
                    ),
                    onTap: () {
                      print('Navigating to ride page with ID: ${ride.id}');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CurrentRidePage(rideId: ride.id),
                        ),
                      );
                    },
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
    print('Fetching filtered rides...');
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('No current user found');
      return [];
    }

    DateTime now = DateTime.now();
    QuerySnapshot snapshot = await _firestore
        .collection('rides')
        .orderBy('timeOfRide')
        .get();

    print('Total rides fetched: ${snapshot.docs.length}');

    // Fetch current user's data only once
    DocumentSnapshot currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    Map<String, dynamic> currentUserData = currentUserDoc.data() as Map<String, dynamic>;

    List<DocumentSnapshot> filteredRides = [];

    for (var ride in snapshot.docs) {
      print('Checking ride with ID: ${ride.id}');
      bool isValid = await _validatePreferences(ride, currentUserData);
      if (isValid) {
        print('Ride ${ride.id} is valid');
        filteredRides.add(ride);
      } else {
        print('Ride ${ride.id} is not valid');
      }
    }

    // Delete rides older than 24 hours
    for (var ride in snapshot.docs) {
      DateTime timeOfRide = ride['timeOfRide'].toDate();
      if (timeOfRide.isBefore(now.subtract(Duration(hours: 24)))) {
        print('Deleting ride with ID: ${ride.id}');
        await ride.reference.delete();
      }
    }

    print('Filtered rides count: ${filteredRides.length}');
    return filteredRides;
  }

  Future<bool> _validatePreferences(DocumentSnapshot ride, Map<String, dynamic> currentUserData) async {
  print('Validating preferences for ride ${ride.id}');
  
  List<String> participants = List<String>.from(ride['participants']);
  print('Participants in ride: $participants');

  for (String participantId in participants) {
    DocumentSnapshot participantDoc = await _firestore.collection('users').doc(participantId).get();
    Map<String, dynamic> participantData = participantDoc.data() as Map<String, dynamic>;

    print('Participant domain: ${participantData['domain']}');
    print('Participant gender: ${participantData['sexAssignedAtBirth']}');

    // Validate current user's preferences against all participants
    if (!_doesUserMatchPreferences(currentUserData, participantData)) {
      print('Current user does not match participant ${participantData['username']} preferences');
      return false;
    }

    // Validate participants' preferences against current user
    if (!_doesUserDataMatchPreferences(participantData, currentUserData)) {
      print('Participant ${participantData['username']} does not match current user preferences');
      return false;
    }
  }

  print('All participants match: true');
  return true;
}

bool _doesUserMatchPreferences(Map<String, dynamic> currentUserData, Map<String, dynamic> targetData) {
  print('Validating user preferences against participant data...');

  Map<String, dynamic> userPrefs = currentUserData['preferences'];

  // Age Range Matching
  int userMinAge = userPrefs['ageRange']['min'];
  int userMaxAge = userPrefs['ageRange']['max'];
  int targetAge = _calculateAge(targetData['birthday']);
  
  print('Checking age: targetAge=$targetAge, range=$userMinAge-$userMaxAge');
  if (targetAge < userMinAge || targetAge > userMaxAge) {
    print('Age does not match: $targetAge is outside range $userMinAge-$userMaxAge');
    return false;
  } else {
    print('Age matches: $targetAge is within range $userMinAge-$userMaxAge');
  }

  // Car Capacity Matching
  int userMinCapacity = userPrefs['minCarCapacity'];
  int userMaxCapacity = userPrefs['maxCarCapacity'];
  int? targetMinCapacity = targetData['preferences']['minCarCapacity'];
  int? targetMaxCapacity = targetData['preferences']['maxCarCapacity'];

  print('Checking car capacity: user=$userMinCapacity-$userMaxCapacity, target=$targetMinCapacity-$targetMaxCapacity');
  if (userMinCapacity > targetMaxCapacity! || userMaxCapacity < targetMinCapacity!) {
    print('Car capacity does not match: $userMinCapacity-$userMaxCapacity vs $targetMinCapacity-$targetMaxCapacity');
    return false;
  } else {
    print('Car capacity matches: $userMinCapacity-$userMaxCapacity vs $targetMinCapacity-$targetMaxCapacity');
  }

  // School Domain Matching (only if the toggle is on)
  String? userDomain = currentUserData['domain'];
  String? targetDomain = targetData['domain'];
  
  if (userPrefs['schoolToggle'] == true) {
    print('Checking domain: userDomain=$userDomain, targetDomain=$targetDomain');
    if (userDomain != targetDomain) {
      print('Domain does not match: $userDomain vs $targetDomain');
      return false;
    } else {
      print('Domain matches: $userDomain vs $targetDomain');
    }
  } else {
    print('Domain check skipped: No school preference set.');
  }

  // Gender Matching (only if the toggle is on)
  String? userGender = currentUserData['sexAssignedAtBirth'];
  String? targetGender = targetData['sexAssignedAtBirth'];

  if (userPrefs['sameGenderToggle'] == true) {
    print('Checking gender: user=$userGender, target=$targetGender');
    if (userGender != targetGender) {
      print('Gender does not match: $userGender vs $targetGender');
      return false;
    } else {
      print('Gender matches: $userGender vs $targetGender');
    }
  } else {
    print('Gender check skipped: No gender preference set.');
  }

  return true;
}

bool _doesUserDataMatchPreferences(Map<String, dynamic> participantData, Map<String, dynamic> currentUserData) {
  print('Validating participant data against user preferences...');

  Map<String, dynamic> participantPrefs = participantData['preferences'];

  // Age Range Matching
  int userAge = _calculateAge(participantData['birthday']);
  int minAge = participantPrefs['ageRange']['min'];
  int maxAge = participantPrefs['ageRange']['max'];

  print('Checking age: userAge=$userAge, range=$minAge-$maxAge');
  if (userAge < minAge || userAge > maxAge) {
    print('User age does not match preferences: $userAge is outside range $minAge-$maxAge');
    return false;
  } else {
    print('User age matches preferences: $userAge is within range $minAge-$maxAge');
  }

  // School Domain Matching (only if the toggle is on)
  String? participantDomain = participantData['domain'];
  String? userDomain = currentUserData['domain'];

  if (participantPrefs['schoolToggle'] == true) {
    print('Checking domain: participantDomain=$participantDomain, userDomain=$userDomain');
    if (participantDomain != userDomain) {
      print('User domain does not match preferences: $participantDomain vs $userDomain');
      return false;
    } else {
      print('User domain matches preferences: $participantDomain vs $userDomain');
    }
  } else {
    print('Domain check skipped: No school preference set.');
  }

  // Gender Matching (only if the toggle is on)
  String? participantGender = participantData['sexAssignedAtBirth'];
  String? userGender = currentUserData['sexAssignedAtBirth'];

  if (participantPrefs['sameGenderToggle'] == true) {
    print('Checking gender: participant=$participantGender, user=$userGender');
    if (participantGender != userGender) {
      print('User gender does not match preferences: $participantGender vs $userGender');
      return false;
    } else {
      print('User gender matches preferences: $participantGender vs $userGender');
    }
  } else {
    print('Gender check skipped: No gender preference set.');
  }

  print('Participant data validation complete.');
  return true;
}

int _calculateAge(String birthday) {
  DateTime birthDate = DateTime.parse(birthday);
  DateTime today = DateTime.now();
  int age = today.year - birthDate.year;
  if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
    age--;
  }
  return age;
}

Future<void> _joinRide(String rideId, List<String> participants) async {
  User? user = _auth.currentUser;
  if (user == null) return;

  if (!participants.contains(user.uid)) {
    participants.add(user.uid);

    // Update ride with new participant and recalculate pickup location
    //String newPickupLocation = await _calculateMidpointAddress(participants);

    // await _firestore.collection('rides').doc(rideId).update({
    //   'participants': participants,
    //   'pickupLocation': newPickupLocation,
    // });

    print('User ${user.uid} joined ride $rideId');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You have joined the ride!')),
    );

    // Redirect to the CurrentRidePage immediately after joining
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => CurrentRidePage(rideId: rideId)),
    );
  } else {
    print('User ${user.uid} is already part of ride $rideId');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You are already part of this ride.')),
    );

    // Redirect to the CurrentRidePage even if already in the ride
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => CurrentRidePage(rideId: rideId)),
    );
  }
}

  Future<List<String>> _getParticipantUsernames(List<String> participantIds) async {
    print('Fetching participant usernames...');
    List<String> usernames = [];
    for (String uid in participantIds) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        usernames.add(userDoc['username']);
        print('Fetched username for $uid: ${userDoc['username']}');
      } else {
        print('No user found with UID: $uid');
      }
    }
    return usernames;
  }

  Future<String> _calculateMidpointAddress(List<String> participants) async {
  print('Calculating midpoint address...');
  List<LatLng> locations = [];

  for (String uid in participants) {
    // Fetch the participant's ride details to get their pickup location
    DocumentSnapshot rideDoc = await _firestore.collection('rides').doc(uid).get();

    // Check if the 'pickupLocation' field exists and is not null
    if (rideDoc.exists) {
      var pickupLocation = rideDoc['pickupLocation'];
      if (pickupLocation != null && pickupLocation['latitude'] != null && pickupLocation['longitude'] != null) {
        locations.add(LatLng(pickupLocation['latitude'], pickupLocation['longitude']));
      } else {
        print('Pickup location data is missing or incomplete for user $uid');
      }
    } else {
      print('No pickup location data for user $uid');
    }
  }

  if (locations.isEmpty) {
    print('No valid pickup locations found. Unable to calculate midpoint.');
    return 'No valid pickup location found';
  }

  double avgLat = locations.map((loc) => loc.latitude).reduce((a, b) => a + b) / locations.length;
  double avgLng = locations.map((loc) => loc.longitude).reduce((a, b) => a + b) / locations.length;

  LatLng midpoint = LatLng(avgLat, avgLng);

  print('Midpoint coordinates: ($avgLat, $avgLng)');

  // Convert midpoint LatLng to an address
  String address = await _getAddressFromLatLng(midpoint);
  print('Midpoint address: $address');
  return address;
}

  Future<String> _getAddressFromLatLng(LatLng position) async {
    print('Fetching address for coordinates: (${position.latitude}, ${position.longitude})');
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$google_maps_api_key';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == 'OK') {
        print('Fetched address: ${jsonResponse['results'][0]['formatted_address']}');
        return jsonResponse['results'][0]['formatted_address'];
      } else {
        print('Failed to fetch address, status: ${jsonResponse['status']}');
        return 'Unknown location';
      }
    } else {
      print('Failed to get address, HTTP status code: ${response.statusCode}');
      return 'Failed to get address';
    }
  }
}