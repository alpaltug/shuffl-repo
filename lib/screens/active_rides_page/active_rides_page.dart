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

import 'package:my_flutter_app/functions/homepage_functions.dart'; 

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
  LatLng? currentPosition;
  DateTime? _rideTime;
  List<DocumentSnapshot> _users = [];
  String? _rideDetailsText;
  int? _estimatedTime;
  String? _pickupAddress;
  List<String> userIds = [];

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<QuerySnapshot>? _participantsSubscription;

  String? _profileImageUrl;
  String? _username;
  String? _fullName;

  Set<Marker> markers = {};
  bool goOnline = true;

  Set<Marker> _participantMarkers = {};  // Set for storing participant markers
  List<String> _participantIds = [];     // List for storing participant IDs
  late GoogleMapController _mapController;

  @override
  void initState() {
    super.initState();

    _loadUserProfile();
    
     // Listen to the current position and update it
    HomePageFunctions.determinePosition(
      _auth,
      _firestore,
      updatePosition,
      _positionStreamSubscription,
      markers,
      updateState,
    );

    // Start listening for online users and update markers in real-time
    HomePageFunctions.fetchOnlineParticipants(
      _auth,
      _firestore,
      updateMarkers, // Pass the updateMarkers callback to update the map
      currentPosition,
      markers,
      widget.rideId,
    );

    _loadActiveRideDetails();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didPopNext() {
    _loadUserProfile();
  }

  // Callback to update 'goOnline' state
  void updateGoOnlineState(bool newGoOnline) {
    setState(() {
      goOnline = newGoOnline;
    });
  }

  void updateState(Function updateFn) {
    setState(() {
      updateFn();
    });
  }

  // Callback to update 'currentPosition'
  void updatePosition(LatLng newPosition) {
    setState(() {
      currentPosition = newPosition;
    });
  }

  // Callback to update 'markers'
  void updateMarkers(Set<Marker> newMarkers) {
    //print('Updating markers');
    setState(() {
      markers = newMarkers;
    });
  }

  // Toggle 'goOnline' and update necessary state variables
  void _toggleGoOnline(bool value) async {
    await HomePageFunctions.toggleGoOnline(
      value,
      currentPosition,
      _auth,
      _firestore,
      updateState,          // Use the callback function for setState
      updatePosition,        // Use the callback function for currentPosition
      updateGoOnlineState,   // Use the callback function for goOnline state
      HomePageFunctions.fetchOnlineParticipants,
      _positionStreamSubscription,
      markers,
      updateMarkers,
      widget.rideId,
    );
  }

  // Fetch online users and update markers
  void _fetchOnlineParticipants() {
    HomePageFunctions.fetchOnlineParticipants(
      _auth,
      _firestore,
      updateMarkers,   // Use the callback function for currentPosition
      currentPosition,
      markers,
      widget.rideId,
    );
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

        _pickupAddress = await HomePageFunctions.getAddressFromLatLng(_pickupLocation!);

        final dropoffLocationsMap = Map<String, String>.from(rideDoc['dropoffLocations']);
        if (dropoffLocationsMap.isNotEmpty) {
          _dropoffAddresses = dropoffLocationsMap.values.toList();
        }

        List<String> userIds = List<String>.from(rideDoc['participants']);
        _participantIds = userIds;
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



  void _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userProfile = await _firestore.collection('users').doc(user.uid).get();

      setState(() {
        _profileImageUrl = userProfile['imageUrl'];
        _username = userProfile['username'];
        _fullName = userProfile['fullName'] ?? 'Shuffl User'; 
        goOnline = true; //changed this line
      });
      //await HomePageFunctions.fetchGoOnlineStatus();
    }
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

  Future<List<LatLng>> _getDropoffLocations() async {
    if (_dropoffAddresses.isEmpty) {
      return [];
    }

    List<LatLng> latLngList = [];
    for (String address in _dropoffAddresses) {
      try {
        LatLng latLng = await HomePageFunctions.getLatLngFromAddress(address);
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
                  showCurrentLocation: false,  // Show user's current location
                  showDirections: true,       // Show directions
                  initialZoom: 14,
                  participantMarkers: markers,  // Pass updated markers
                  participantIds: _participantIds, // Pass participant
                  userId: _auth.currentUser?.uid,
                ),
              ),
              // CURRENTLY NOT IMPLEMENTED (TOGGLE ONLINE STATUS) FOR ACTIVE RIDES BUT KEEPING THE STRUCTURE
            //   Padding(
            //   padding: const EdgeInsets.all(16.0),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       const Text('Go Online', style: TextStyle(color: Colors.black)),
            //       Switch(
            //         value: goOnline, // Set the switch's value based on Firestore data
            //         onChanged: (value) {
            //           _toggleGoOnline(value); // Toggle online status without full page reload
            //         },
            //         activeColor: Colors.yellow,
            //       ),
            //     ],
            //   ),
            // ),
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