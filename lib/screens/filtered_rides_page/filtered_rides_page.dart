import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/location_search_screen/location_search_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:my_flutter_app/screens/waiting_page/waiting_page.dart';
import 'package:my_flutter_app/widgets/ride_card.dart';
import 'package:my_flutter_app/widgets/ride_details_popup.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';
import 'package:my_flutter_app/widgets/find_ride_widget.dart';

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

  Future<List<Map<String, String>>> _getParticipantDetails(List<String> uids) async {
    List<Map<String, String>> participantDetails = [];
    for (String uid in uids) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      String username = userDoc['username'] ?? 'Unknown';
      String fullName = userDoc['fullName'] ?? 'Unknown';
      String imageUrl = userDoc['imageUrl'] ?? '';
      participantDetails.add({
        'uid': uid,
        'username': username,
        'fullName': fullName,
        'imageUrl': imageUrl,
      });
    }
    return participantDetails;
  }

  Future<void> _joinRide(String rideId, String pickupLocation, String dropoffLocation, List<String> participants) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    LatLng newPickupLatLng = await _getLatLngFromAddress(pickupLocation);
    LatLng newDropoffLatLng = await _getLatLngFromAddress(dropoffLocation);

    DocumentSnapshot rideDoc = await _firestore.collection('rides').doc(rideId).get();
    Map<String, dynamic> rideData = rideDoc.data() as Map<String, dynamic>;

    Map<String, dynamic> pickupLocationsMap = rideData['pickupLocations'] ?? {};
    Map<String, dynamic> dropoffLocationsMap = rideData['dropoffLocations'] ?? {};

    List<LatLng> existingPickups = [];
    for (var location in pickupLocationsMap.values) {
      LatLng latLng = await _getLatLngFromAddress(location);
      existingPickups.add(latLng);
    }

    List<LatLng> existingDropoffs = [];
    for (var location in dropoffLocationsMap.values) {
      LatLng latLng = await _getLatLngFromAddress(location);
      existingDropoffs.add(latLng);
    }

    bool isValid = await _isValidRoute(
      existingPickups,
      existingDropoffs,
      newPickupLatLng,
      newDropoffLatLng,
    );

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Your pickup/dropoff location is too far, enter closer values or schedule a ride of your own.')),
      );
      return;
    }

    if (!participants.contains(user.uid)) {
      participants.add(user.uid);

      await _firestore.collection('rides').doc(rideId).update({
        'participants': participants,
        if (pickupLocation.isNotEmpty)
          'pickupLocations.${user.uid}': pickupLocation,
        if (dropoffLocation.isNotEmpty)
          'dropoffLocations.${user.uid}': dropoffLocation,
        'readyStatus.${user.uid}': false,
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

  Future<bool> _isValidRoute(
    List<LatLng> existingPickups,
    List<LatLng> existingDropoffs,
    LatLng newPickup,
    LatLng newDropoff,
  ) async {
    print(
        'Validating route with existingPickups: $existingPickups, existingDropoffs: $existingDropoffs, newPickup: $newPickup, newDropoff: $newDropoff');

    List<LatLng> originalRoute = [...existingPickups, ...existingDropoffs];

    List<LatLng> newRoute = [...existingPickups, newPickup, ...existingDropoffs, newDropoff];

    double originalRouteDistance = await _getRouteDistance(originalRoute);
    double newRouteDistance = await _getRouteDistance(newRoute);

    print(
        'Original route distance: $originalRouteDistance, New route distance: $newRouteDistance');

    const double maxAllowedIncrease = 0.2; 
    if (newRouteDistance <= originalRouteDistance * (1 + maxAllowedIncrease)) {
      print('Route is valid, distance increase is within allowed range.');
      return true;
    }

    print('Route is invalid, distance increase exceeds allowed range.');
    return false;
  }

  Future<double> _getRouteDistance(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return 0.0;

    String origin = '${waypoints.first.latitude},${waypoints.first.longitude}';
    String destination =
        '${waypoints.last.latitude},${waypoints.last.longitude}';

    String waypointsParam = '';
    if (waypoints.length > 2) {
      waypointsParam = '&waypoints=optimize:true|' +
          waypoints
              .sublist(1, waypoints.length - 1)
              .map((latLng) => '${latLng.latitude},${latLng.longitude}')
              .join('|');
    }

    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination$waypointsParam&key=$google_maps_api_key';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['routes'] != null && data['routes'].isNotEmpty) {
        return data['routes'][0]['legs']
            .map<double>((leg) {
              var distanceValue = leg['distance']['value'];
              if (distanceValue != null && distanceValue is num) {
                return distanceValue.toDouble();
              }
              return 0.0;
            })
            .fold(0.0, (sum, value) => sum + value);
      }
    }

    throw Exception('Failed to fetch directions');
  }

  void _showRideDetailsPopup(BuildContext context, DocumentSnapshot ride, List<Map<String, String>> participants) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (context) {
        String? pickupLocation;
        String? dropoffLocation;

        return RideWidget(
          onSubmit: (pickupLocation, dropoffLocation) {
            _joinRide(ride.id, pickupLocation, dropoffLocation, List<String>.from(ride['participants']));
          },
          onLocationSearch: (isPickup, onSelectAddress) => _navigateToLocationSearch(isPickup, onSelectAddressCallback: onSelectAddress),
          isJoinRide: true,
          participants: participants,
        );
      },
    );
  }

  void _navigateToLocationSearch(bool isPickup, {required Function(String) onSelectAddressCallback}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSearchScreen(
          isPickup: isPickup,
          currentPosition: _currentPosition,
          onSelectAddress: (address) {
            onSelectAddressCallback(address);
          },
        ),
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
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            style: const TextStyle(color: Colors.black),
            readOnly: true,
            onTap: () => _navigateToLocationSearch(true, onSelectAddressCallback: (address) {
              setState(() {
                _pickupController.text = address;
              });
            }),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _dropoffController,
            decoration: InputDecoration(
              labelText: 'Dropoff Location',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            style: const TextStyle(color: Colors.black),
            readOnly: true,
            onTap: () => _navigateToLocationSearch(false, onSelectAddressCallback: (address) {
              setState(() {
                _dropoffController.text = address;
              });
            }),
          ),
          const SizedBox(height: 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _pickupFilter = _pickupController.text;
                    _dropoffFilter = _dropoffController.text;
                    _filteredRidesFuture = _fetchFilteredRides();
                  });
                },
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _pickupController.clear();
                    _dropoffController.clear();
                    _pickupFilter = null;
                    _dropoffFilter = null;
                    _filteredRidesFuture = _fetchFilteredRides();
                  });
                },
                child: const Text(
                  'Remove Filters',
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<DocumentSnapshot>> _fetchFilteredRides() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      DocumentSnapshot currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      Map<String, dynamic>? currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
      List<String> blockedUsers = currentUserData != null && currentUserData.containsKey('blockedUsers') 
          ? List<String>.from(currentUserData['blockedUsers']) 
          : [];
      List<String> blockedBy = currentUserData != null && currentUserData.containsKey('blockedBy') 
          ? List<String>.from(currentUserData['blockedBy']) 
          : [];

      DateTime now = DateTime.now();
      QuerySnapshot snapshot = await _firestore.collection('rides').orderBy('timeOfRide').get();
      List<DocumentSnapshot> filteredRides = [];

      for (var ride in snapshot.docs) {
        bool isComplete = ride['isComplete'] ?? false;
        List<String> participants = List<String>.from(ride['participants']);
        bool containsBlockedUser = participants.any((participant) => blockedUsers.contains(participant) || blockedBy.contains(participant));

        if (!isComplete && !participants.contains(currentUser.uid) && !containsBlockedUser) {
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
    } catch (e) {
      print('Error fetching rides: $e');
      return [];
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Available Rides',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold, 
          ),
        ),
        backgroundColor: kBackgroundColor,
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: _filteredRidesFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'), // Add your logo path here
                  );
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

                    return FutureBuilder<List<Map<String, String>>>(
                      future: _getParticipantDetails(List<String>.from(ride['participants'])),
                      builder: (context, participantsSnapshot) {
                        if (!participantsSnapshot.hasData) {
                          return const ListTile(
                            title: Text('Loading...'),
                          );
                        }

                        final participants = participantsSnapshot.data!;

                        return GestureDetector(
                          onTap: () => _showRideDetailsPopup(context, ride, participants),
                          child: RideCard(
                            ride: ride.data() as Map<String, dynamic>,
                            participantUsernames: participants.map((p) => p['username']!).toList(),
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
}