import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_flutter_app/screens/location_search_screen/location_search_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:my_flutter_app/screens/location_search_screen/location_search_screen.dart';
import 'dart:convert';
import 'package:my_flutter_app/screens/waiting_page/waiting_page.dart';




final google_maps_api_key = 'AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk';


class FilteredRidesPage extends StatefulWidget {
  const FilteredRidesPage({super.key});

  @override
  _FilteredRidesPageState createState() => _FilteredRidesPageState();
}

class _FilteredRidesPageState extends State<FilteredRidesPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  LatLng? _currentPosition;


  String? _pickupFilter;
  String? _dropoffFilter;

  late Future<List<DocumentSnapshot>> _filteredRidesFuture;

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredRidesFuture = _fetchFilteredRides();
    _getCurrentPosition();
  }

  void _getCurrentPosition() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _currentPosition = LatLng(position.latitude, position.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Rides'),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: _filteredRidesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredRides = snapshot.data!;
                print('Number of filtered rides: ${filteredRides.length}');

                if (filteredRides.isEmpty) {
                  return const Center(
                    child: Text(
                      'No rides available that match your preferences.',
                      style: TextStyle(color: Colors.black), 
                    ),
                  );
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
                              'Pickup: ${ride['pickupLocations'].values.join(", ")}',
                              style: const TextStyle(color: Colors.black),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dropoff: ${ride['dropoffLocations'].values.join(", ")}'),
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _pickupController,
            decoration: InputDecoration(
              labelText: 'Pickup Location',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_on),
            ),
            style: const TextStyle(color: Colors.black),
            readOnly: true,
            onTap: () => _navigateToLocationSearch(true),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _dropoffController,
            decoration: InputDecoration(
              labelText: 'Dropoff Location',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_on),
            ),
            style: const TextStyle(color: Colors.black),
            readOnly: true,
            onTap: () => _navigateToLocationSearch(false),
          ),
          const SizedBox(height: 8.0),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _pickupFilter = _pickupController.text;
                _dropoffFilter = _dropoffController.text;
                _filteredRidesFuture = _fetchFilteredRides();
              });
            },
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }

  Future<List<DocumentSnapshot>> _fetchFilteredRides() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    DateTime now = DateTime.now();
    QuerySnapshot snapshot = await _firestore.collection('rides').orderBy('timeOfRide').get();

    List<DocumentSnapshot> filteredRides = [];

    for (var ride in snapshot.docs) {
      bool isComplete = ride['isComplete'] ?? false;
      List<String> participants = List<String>.from(ride['participants']);

      if (!isComplete && !participants.contains(currentUser.uid)) {
        if (_pickupFilter != null || _dropoffFilter != null) {
          bool pickupMatch = await _matchesLocation(_pickupFilter, ride['pickupLocations']);
          bool dropoffMatch = await _matchesLocation(_dropoffFilter, ride['dropoffLocations']);

          if ((_pickupFilter == null || pickupMatch) && (_dropoffFilter == null || dropoffMatch)) {
            filteredRides.add(ride);
          }
        } else {
          filteredRides.add(ride);
        }
      }
    }

    for (var ride in snapshot.docs) {
      DateTime timeOfRide = ride['timeOfRide'].toDate();
      if (timeOfRide.isBefore(now.subtract(const Duration(hours: 24)))) {
        await ride.reference.delete();
      }
    }

    return filteredRides;
  }

  Future<bool> _matchesLocation(String? filter, Map<String, dynamic> locations) async {
    if (filter == null || filter.isEmpty) {
      return true;
    }

    LatLng filterLatLng = await _getLatLngFromAddress(filter);

    for (var location in locations.values) {
      LatLng locationLatLng = await _getLatLngFromAddress(location);
      double distanceInMeters = Geolocator.distanceBetween(
        filterLatLng.latitude,
        filterLatLng.longitude,
        locationLatLng.latitude,
        locationLatLng.longitude,
      );

      if (distanceInMeters <= 50) {
        return true;
      }
    }
    return false;
  }

  Future<LatLng> _getLatLngFromAddress(String address) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$google_maps_api_key');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        } else {
          throw Exception('No locations found for the given address: $address');
        }
      } else {
        throw Exception(
            'Failed to get location from address: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Failed to get location from address: $address, error: $e');
      throw Exception('Failed to get location from address: $e');
    }
  }

  Future<List<String>> _getParticipantUsernames(List<String> uids) async {
    List<String> usernames = [];
    for (String uid in uids) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      String username = userDoc['username'] ?? 'Unknown';
      usernames.add(username);
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

  void _navigateToLocationSearch(bool isPickup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSearchScreen(
          isPickup: isPickup,
          currentPosition: _currentPosition,
          onSelectAddress: (address) {
            if (isPickup) {
              _pickupController.text = address;
            } else {
              _dropoffController.text = address;
            }
          },
        ),
      ),
    );
  }
}