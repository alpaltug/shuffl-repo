import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/rating_page/rating_page.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/screens/group_chats_screen/group_chats_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final google_maps_api_key = 'AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk';

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
  List<LatLng> _pickupLocations = [];
  List<LatLng> _dropoffLocations = [];
  DateTime? _rideTime;
  LatLng loc = LatLng(0, 0);
  final LatLng _center = const LatLng(37.8715, -122.2730); // Campus location

  @override
  void initState() {
    super.initState();
    _loadActiveRideDetails();
  }

  Future<void> _loadActiveRideDetails() async {
    try {
      DocumentSnapshot rideDoc = await FirebaseFirestore.instance
          .collection('active_rides')
          .doc(widget.rideId)
          .get();

      if (rideDoc.exists) {
        bool isFinished = false;

        if (mounted && isFinished) {
          List<String> participants = List<String>.from(rideDoc['participants']);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RatingPage(
                rideId: widget.rideId,
                participants: participants,
              ),
            ),
          );
          return;
        }

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

        _pickupLocations = await _getLocationsFromAddresses(
          Map<String, String>.from(rideDoc['pickupLocations']),
        );

        _dropoffLocations = await _getLocationsFromAddresses(
          Map<String, String>.from(rideDoc['dropoffLocations']),
        );

        loc = _pickupLocations.isNotEmpty ? _pickupLocations[0] : _center;

        if (mounted) {
          setState(() {
            _rideData = rideDoc;
            _rideTime = (rideDoc['timeOfRide'] as Timestamp).toDate();
            _users = userDocs;
          });

          // Call _loadMarkers only after setting _rideData and _users
          _loadMarkers();
        }

      } else {
        print('Ride document does not exist.');
      }
    } catch (e) {
      if (mounted) {
        print('Error loading ride details: $e');
      }
    }
  }

  Future<List<LatLng>> _getLocationsFromAddresses(Map<String, String> locationsMap) async {
    List<LatLng> locations = [];
    for (var address in locationsMap.values) {
      LatLng location = await _getLatLngFromAddress(address);
      locations.add(location);
    }
    return locations;
  }

  Future<void> _loadMarkers() async {
    Set<Marker> markers = {};

    for (LatLng location in _pickupLocations) {
      markers.add(Marker(
        markerId: MarkerId("pickup-${location.latitude}-${location.longitude}"),
        position: location,
        infoWindow: InfoWindow(
          title: 'Pickup Location',
        ),
      ));
    }

    for (LatLng location in _dropoffLocations) {
      markers.add(Marker(
        markerId: MarkerId("dropoff-${location.latitude}-${location.longitude}"),
        position: location,
        infoWindow: InfoWindow(
          title: 'Dropoff Location',
        ),
      ));
    }

    setState(() {
      _markers = markers;
    });
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (loc != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(loc, 15.0),
      );
    } else {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_center, 15.0), // Default to Berkeley if no location
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Duration? timeRemaining = _rideTime != null ? _rideTime!.difference(DateTime.now()) : null;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Active Ride',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kBackgroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupChatScreen(chatId: widget.rideId),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pickupLocations.isNotEmpty || _dropoffLocations.isNotEmpty)
            Container(
              height: 200,
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: loc,
                  zoom: 14,
                ),
                markers: _markers,
              ),
            ),
          if (timeRemaining != null && timeRemaining > Duration.zero)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 3,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    HourglassAnimation(duration: timeRemaining),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Starts in:',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        CountdownTimer(duration: timeRemaining),
                      ],
                    ),
                  ],
                ),
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
                    color: Colors.green[50],
                    margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl) : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                      ),
                      title: Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        '@$username',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      onTap: () {
                        if (user.id == _auth.currentUser?.uid) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UserProfile(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ViewUserProfile(uid: user.id),
                            ),
                          );
                        }
                      },
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

class HourglassAnimation extends StatefulWidget {
  final Duration duration;

  const HourglassAnimation({Key? key, required this.duration}) : super(key: key);

  @override
  _HourglassAnimationState createState() => _HourglassAnimationState();
}

class _HourglassAnimationState extends State<HourglassAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));

    _opacityAnimation = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return RotationTransition(
          turns: _rotationAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Icon(
              Icons.hourglass_top,
              size: 40,
              color: Colors.yellow[700],
            ),
          ),
        );
      },
    );
  }
}
