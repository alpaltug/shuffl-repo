import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/screens/active_rides_page/active_rides_page.dart';

class WaitingPage extends StatefulWidget {
  final String rideId;
  const WaitingPage({required this.rideId, Key? key}) : super(key: key);

  @override
  _WaitingPageState createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> {
  late GoogleMapController _mapController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Set<Marker> _markers = {};
  List<DocumentSnapshot> _users = [];
  List<String> _pickupLocations = [];
  Map<String, bool> _readyStatus = {};
  int _participantsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadRideDetails();
  }

  Future<void> _loadRideDetails() async {
    DocumentSnapshot rideDoc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .get();

    if (rideDoc.exists) {
      setState(() {
        _pickupLocations = List<String>.from(rideDoc['pickupLocations']);
        _readyStatus = Map<String, bool>.from(rideDoc['readyStatus'] ?? {});
        _participantsCount = (rideDoc['participants'] as List).length;
        _loadMarkers();
      });

      List<String> userIds = List<String>.from(rideDoc['participants']);
      List<DocumentSnapshot> userDocs = [];
      for (String uid in userIds) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        userDocs.add(userDoc);
      }

      setState(() {
        _users = userDocs;
      });
    }
  }

  Future<void> _loadMarkers() async {
    Set<Marker> markers = {};

    for (String address in _pickupLocations) {
      LatLng location = await _getLatLngFromAddress(address);
      markers.add(Marker(
        markerId: MarkerId(address),
        position: location,
      ));
    }

    setState(() {
      _markers = markers;
    });
  }

  Future<LatLng> _getLatLngFromAddress(String address) async {
    List<Location> locations = await locationFromAddress(address);
    if (locations.isNotEmpty) {
      return LatLng(locations.first.latitude, locations.first.longitude);
    } else {
      throw Exception('No locations found for the given address.');
    }
  }

  Future<void> _toggleReadyStatus(String userId) async {
    if (userId != _auth.currentUser?.uid) return; // Lock other users' buttons

    DocumentReference rideDocRef = FirebaseFirestore.instance.collection('rides').doc(widget.rideId);

    bool currentStatus = _readyStatus[userId] ?? false;
    setState(() {
      _readyStatus[userId] = !currentStatus;
    });

    await rideDocRef.update({
      'readyStatus.$userId': !currentStatus,
    });

    // Check if all participants are ready
    if (_readyStatus.values.every((status) => status)) {
      await _init_ride(rideDocRef);
    }
  }

  Future<void> _init_ride(DocumentReference rideDocRef) async {
    DocumentSnapshot rideDoc = await rideDocRef.get();
    Map<String, dynamic> rideData = rideDoc.data() as Map<String, dynamic>;

    // Calculate single pickup location (currently just returns the first)
    String singlePickupLocation = _calculateSinglePickupLocation(List<String>.from(rideData['pickupLocations']));
    rideData['pickupLocation'] = singlePickupLocation;

    // Ensure ride time is not in the past
    DateTime rideTime = rideData['timeOfRide'].toDate();
    DateTime now = DateTime.now();
    rideData['timeOfRide'] = Timestamp.fromDate(rideTime.isBefore(now) ? now : rideTime);

    // Remove from rides collection
    await rideDocRef.delete();

    // Add to active_rides collection and get the new document ID
    DocumentReference activeRideDocRef = await FirebaseFirestore.instance
        .collection('active_rides')
        .add(rideData);

    // Navigate to active ride page using the new document ID
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ActiveRidesPage(rideId: activeRideDocRef.id)),
    );
}


  String _calculateSinglePickupLocation(List<String> pickupLocations) {
    // For now, return the first pickup location
    return pickupLocations.isNotEmpty ? pickupLocations[0] : 'Unknown location';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Page'),
      ),
      body: Column(
        children: [
          if (_pickupLocations.isNotEmpty)
            Container(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _markers.isNotEmpty
                      ? _markers.first.position
                      : LatLng(0, 0),
                  zoom: 14,
                ),
                markers: _markers,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              ),
            ),
          if (_users.isEmpty)
            const Text('No users found.', style: TextStyle(color: Colors.black))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  var user = _users[index];
                  var username = user['username'] ?? '';
                  var fullName = user['fullName'] ?? '';
                  var imageUrl = user.data().toString().contains('imageUrl') ? user['imageUrl'] : null;
                  bool isReady = _readyStatus[user.id] ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                                ? NetworkImage(imageUrl)
                                : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                Text(
                                  '@$username',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: user.id == _auth.currentUser?.uid
                                ? () => _toggleReadyStatus(user.id)
                                : null, // Lock button for others
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isReady ? Colors.green : Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18.0),
                              ),
                            ),
                            child: Text(isReady ? 'Unready' : 'Ready'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
