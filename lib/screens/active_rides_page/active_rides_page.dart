import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/rating_page/rating_page.dart';
import 'package:my_flutter_app/screens/ride_group_chats_screen/ride_group_chats_screen.dart';
import 'package:my_flutter_app/widgets/map_widget.dart';
import 'package:my_flutter_app/widgets/ride_info_widget.dart';
import 'package:my_flutter_app/widgets/participant_list_widget.dart';
import 'package:my_flutter_app/widgets/create_custom_marker.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';



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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  LatLng? _pickupLocation;
  List<String> _dropoffAddresses = [];
  LatLng? _currentPosition;
  DateTime? _rideTime;
  List<DocumentSnapshot> _users = [];
  String? _rideDetailsText;
  int? _estimatedTime;
  String? _pickupAddress;

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<QuerySnapshot>? _participantsSubscription;

  bool _isMapReady = false; // Track if the map is ready



  bool _goOnline = false;
  Set<Marker> _participantMarkers = {};  // Set for storing participant markers
  late GoogleMapController _mapController;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _loadActiveRideDetails();
    _fetchGoOnlineStatus();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();  // <-- Cancel the subscription
    //routeObserver.unsubscribe(this);
    super.dispose();
  }
  

  Future<void> _loadActiveRideDetails() async {
    try {
      DocumentSnapshot rideDoc = await FirebaseFirestore.instance
          .collection('active_rides')
          .doc(widget.rideId)
          .get();

      if (rideDoc.exists) {
        _pickupLocation = LatLng(
          rideDoc['pickupLocation']['latitude'],
          rideDoc['pickupLocation']['longitude'],
        );

        _pickupAddress = await _getAddressFromLatLng(_pickupLocation!);

        final dropoffLocationsMap = Map<String, String>.from(rideDoc['dropoffLocations']);
        if (dropoffLocationsMap.isNotEmpty) {
          _dropoffAddresses = dropoffLocationsMap.values.toList();
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

        if (mounted) {
          setState(() {
            _rideTime = (rideDoc['timeOfRide'] as Timestamp).toDate();
            _users = userDocs;
            _rideDetailsText = "Pickup: $_pickupAddress";
            _estimatedTime = _calculateEstimatedTime(_rideTime!);
          });
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

  Future<void> _updateGoOnlineStatus(bool value) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'goOnline': value});
    }
  }


  Future<void> _toggleGoOnline(bool value) async {
    await _updateGoOnlineStatus(value);

    setState(() {
      _goOnline = value;
    });

    if (value) {
      if (_isMapReady) {
        _determinePosition();  // Start position tracking
      }
    } else {
      _positionStreamSubscription?.cancel();  // Stop position tracking
    }

    _fetchOnlineParticipants();  // Fetch online participants every time toggle changes
  }



  Future<void> _fetchGoOnlineStatus() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        setState(() {
          _goOnline = userDoc['goOnline'] ?? false;  // Set the initial value of goOnline
        });
      }
    }
  }


  Future<void> _fetchOnlineParticipants() async {
  _participantsSubscription?.cancel();

  _participantsSubscription = FirebaseFirestore.instance
      .collection('users')
      .where('goOnline', isEqualTo: true)
      .where('uid', whereIn: _users.map((user) => user.id).toList())
      .snapshots()
      .listen((QuerySnapshot userSnapshot) async {
        Set<Marker> updatedMarkers = {};
        Map<String, int> locationCount = {};

        for (var doc in userSnapshot.docs) {
          var userData = doc.data() as Map<String, dynamic>;

          if (userData.containsKey('lastPickupLocation')) {
            GeoPoint location = userData['lastPickupLocation'];
            LatLng participantPosition = LatLng(location.latitude, location.longitude);

            // Adjusting multiple participants at the same location
            String locationKey = '${location.latitude},${location.longitude}';
            if (locationCount.containsKey(locationKey)) {
              locationCount[locationKey] = locationCount[locationKey]! + 1;
            } else {
              locationCount[locationKey] = 1;
            }

            double offset = 0.0001 * (locationCount[locationKey]! - 1);
            LatLng adjustedPosition = LatLng(location.latitude + offset, location.longitude + offset);

            String? profileImageUrl = userData['imageUrl'];
            BitmapDescriptor markerIcon = await createCustomMarkerWithImage(profileImageUrl!);

            updatedMarkers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: adjustedPosition,
                icon: markerIcon,
                infoWindow: InfoWindow(
                  title: userData['username'],
                ),
              ),
            );
          }
        }

        // Avoid unnecessary state updates
        if (mounted) {
          setState(() {
            _participantMarkers = updatedMarkers;
          });
        }
      });
}



  Future<void> _updateUserLocationInFirestore(LatLng currentPosition) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'lastPickupLocation': GeoPoint(currentPosition.latitude, currentPosition.longitude),
        'lastPickupTime': FieldValue.serverTimestamp(),
      });
    }
  }



  Future<void> _determinePosition() async {
    if (!_goOnline || !_isMapReady) return;  // Ensure map is ready before proceeding

    _positionStreamSubscription?.cancel();

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) async {
      LatLng currentPosition = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = currentPosition;
        });
      }

      User? user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'lastPickupLocation': GeoPoint(currentPosition.latitude, currentPosition.longitude),
          'lastPickupTime': FieldValue.serverTimestamp(),
        });

        // Update the user's marker with the profile image asynchronously
        _updateUserLocationInFirestore(currentPosition);
        await _updateUserMarker(currentPosition);

        // Only animate camera if the map is ready and controller is initialized
        if (_isMapReady && _mapController != null) {
          _mapController.animateCamera(
            CameraUpdate.newLatLngZoom(currentPosition, 15.0),
          );
        }
      }

      // Fetch other online participants
      _fetchOnlineParticipants();
    });
  }








  Future<void> _updateUserMarker(LatLng position) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    String? profileImageUrl = userDoc['imageUrl'];

    BitmapDescriptor markerIcon;
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      markerIcon = await createCustomMarkerWithImage(profileImageUrl);
    } else {
      markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }

    setState(() {
      _participantMarkers.removeWhere((marker) => marker.markerId.value == 'current_user');
      _participantMarkers.add(
        Marker(
          markerId: const MarkerId("current_user"),
          position: position,
          icon: markerIcon,
        ),
      );
    });
  }



  int _calculateEstimatedTime(DateTime rideTime) {
    return rideTime.difference(DateTime.now()).inMinutes;
  }

  String _getRideTimeText() {
    if (_rideTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(_rideTime!).inMinutes;

    if (difference.abs() <= 15) {
      return 'NOW: ${DateFormat('kk:mm').format(_rideTime!)}';
    } else if (difference > 60) {
      return 'Elapsed: ${DateFormat('kk:mm').format(_rideTime!)}';
    } else {
      return 'Ride Time: ${DateFormat('yyyy-MM-dd – kk:mm').format(_rideTime!)}';
    }
  }

  Future<String> _getAddressFromLatLng(LatLng position) async {
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$google_maps_api_key';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == 'OK') {
        return jsonResponse['results'][0]['formatted_address'];
      } else {
        return 'Unknown location';
      }
    } else {
      return 'Failed to get address';
    }
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

  Future<List<LatLng>> _getDropoffLocations() async {
    if (_dropoffAddresses.isEmpty) {
      return [];
    }

    List<LatLng> latLngList = [];
    for (String address in _dropoffAddresses) {
      try {
        LatLng latLng = await _getLatLngFromAddress(address);
        latLngList.add(latLng);
      } catch (e) {
        print('Failed to convert address: $address to LatLng, error: $e');
      }
    }

    return latLngList;
  }

  void _endRide() async {
    bool? confirmEnd = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Ride', style: TextStyle(color: Colors.black)),
        content: Text('Are you sure you want to end the ride? You will be directed to the rating screen.', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('End Ride', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmEnd == true) {
      // Remove current user from participants
      String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null) {
        await FirebaseFirestore.instance
            .collection('active_rides')
            .doc(widget.rideId)
            .update({
          'participants': FieldValue.arrayRemove([currentUserId]),
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RatingPage(rideId: widget.rideId, participants: _users.map((e) => e.id).toList()),
        ),
      );
    }
  }

  @override
Widget build(BuildContext context) {
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
                builder: (context) => RideGroupChatScreen(
                  rideId: widget.rideId,
                  isActiveRide: true,
                ),
              ),
            );
          },
        ),
      ],
    ),
    body: FutureBuilder<List<LatLng>>(
      future: _getDropoffLocations(), // Fetch dropoff locations asynchronously
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'), // Add your logo path here
          );
        } else if (snapshot.hasError) {
          return const Center(
            child: LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'), // Add your logo path here
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'), // Add your logo path here
          );
        }

        final dropoffLocations = snapshot.data ?? [];

        return Column(
          children: [
            if (_pickupLocation != null)
              Expanded(
                child: MapWidget(
                  pickupLocation: _pickupLocation!,
                  dropoffLocations: dropoffLocations,
                  showCurrentLocation: true,  // Show user's current location
                  showDirections: true,       // Show directions
                  initialZoom: 14,
                  participantMarkers: _participantMarkers,  // Pass updated markers
                ),
              ),
              Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Go Online', style: TextStyle(color: Colors.black)),
                  Switch(
                    value: _goOnline, // Set the switch's value based on Firestore data
                    onChanged: (value) {
                      _toggleGoOnline(value); // Toggle online status without full page reload
                    },
                    activeColor: Colors.yellow,
                  ),
                ],
              ),
            ),
            if (_rideDetailsText != null && _estimatedTime != null)
              RideInfoWidget(
                rideDetails: _rideDetailsText!,
                rideTimeText: _getRideTimeText(),
                dropoffAddresses: _dropoffAddresses, // Pass dropoff addresses as a list
              ),
            if (_users.isNotEmpty)
              Expanded(
                child: ParticipantListWidget(users: _users),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _endRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Red button for ending the ride
                ),
                child: const Text('End Ride'),
              ),
            ),
          ],
        );
      },
    ),
  );
}
}