import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/screens/group_chats_screen/group_chats_screen.dart';

class ActiveRidesPage extends StatefulWidget {
  final String rideId;
  const ActiveRidesPage({required this.rideId, Key? key}) : super(key: key);

  @override
  _ActiveRidesPageState createState() => _ActiveRidesPageState();
}

class _ActiveRidesPageState extends State<ActiveRidesPage> {
  late GoogleMapController _mapController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Set<Marker> _markers = {};
  DocumentSnapshot? _rideData;
  List<DocumentSnapshot> _users = [];
  DateTime? _rideTime;

  @override
  void initState() {
    super.initState();
    _loadActiveRideDetails();
  }

  Future<void> _loadActiveRideDetails() async {
    DocumentSnapshot rideDoc = await FirebaseFirestore.instance
        .collection('active_rides')
        .doc(widget.rideId)
        .get();

    if (rideDoc.exists) {
      setState(() {
        _rideData = rideDoc;
        _rideTime = (rideDoc['timeOfRide'] as Timestamp).toDate();
        _loadMarkers();
      });

      List<String> userIds = List<String>.from(rideDoc['participants']);
      List<DocumentSnapshot> userDocs = [];
      for (String uid in userIds) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          userDocs.add(userDoc);
        } else {
          print('User with UID $uid not found.');
        }
      }

      if (mounted) {
        setState(() {
          _users = userDocs;
        });
      }

      print('Number of users found: ${_users.length}');
    } else {
      print('Ride document does not exist.');
    }
  }

  Future<void> _loadMarkers() async {
    if (_rideData == null) return;

    User? user = _auth.currentUser;
    if (user == null) return;

    // Retrieve the pickup location for the current user
    String address = _rideData!['pickupLocations'][user.uid];
    LatLng location = await _getLatLngFromAddress(address);

    setState(() {
      _markers.add(Marker(
        markerId: MarkerId(address),
        position: location,
      ));
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

  @override
  Widget build(BuildContext context) {
    Duration? timeRemaining = _rideTime != null ? _rideTime!.difference(DateTime.now()) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Ride'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupChatScreen(rideId: widget.rideId),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_rideData != null)
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
          if (timeRemaining != null && timeRemaining > Duration.zero)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_top,
                    size: 30,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Starts in:',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(width: 10),
                  CountdownTimer(duration: timeRemaining),
                ],
              ),
            ),
          if (_rideTime != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Ride Time: ${DateFormat('yyyy-MM-dd – kk:mm').format(_rideTime!)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          const SizedBox(height: 10),
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
}

class CountdownTimer extends StatelessWidget {
  final Duration duration;

  const CountdownTimer({Key? key, required this.duration}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Duration>(
      tween: Tween(begin: duration, end: Duration.zero),
      duration: duration,
      onEnd: () {
        print('Ride starting now!');
      },
      builder: (BuildContext context, Duration value, Widget? child) {
        return Text(
          _formatTimeRemaining(value),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
        );
      },
    );
  }

  String _formatTimeRemaining(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m ${duration.inSeconds.remainder(60)}s';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}