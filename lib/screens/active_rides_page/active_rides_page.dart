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
  bool _isLoading = true;  // Initially, data is being loaded (added this as a new feature to avoid non-loading issues)


  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<QuerySnapshot>? _participantsSubscription;

  Set<Polyline> _polylines = {};

  String? _profileImageUrl;
  String? _username;
  String? _fullName;

  Set<Marker> markers = {};
  bool goOnline = false;

  //Set<Marker> participantMarkers = {};  // Set for storing participant markers
  List<String> _participantIds = [];     // List for storing participant IDs
  late GoogleMapController _mapController;

  //Future<List<LatLng>>? _dropoffLocationsFuture;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadActiveRideDetails().then((_) {
      if (_pickupLocation != null) {
        // Only proceed if _pickupLocation is successfully loaded
        HomePageFunctions.determinePosition(
          _auth,
          _firestore,
          updatePosition,
          _positionStreamSubscription,
          markers,
          updateState,
        );
        _fetchOnlineParticipants();
        _updateDirections();
      } else {
        print('Error: Pickup location is still null after load.');
      }
      // Set loading to false once data is fetched
      setState(() {
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _participantsSubscription?.cancel();
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

  // Callback to update 'currentPosition'
void updatePosition(LatLng newPosition) {
  //print('Updating position with new position: $newPosition');
  if (mounted) {
    setState(() {
      currentPosition = newPosition;
    });
  }
}

// Callback to update 'goOnline' state
void updateGoOnlineState(bool newGoOnline) {
  if (mounted) {
    setState(() {
      goOnline = newGoOnline;
    });
  }
}

// Update state with a function, only if mounted
void updateState(Function updateFn) {
  if (mounted) {
    setState(() {
      updateFn();
    });
  }
}

Future<BitmapDescriptor> _createCustomMarkerIcon(BuildContext context) async {
  return BitmapDescriptor.fromAssetImage(
    const ImageConfiguration(size: Size(48, 48)), // Adjust size as needed
    'assets/icons/marker.png', 
  );
}


void updateMarkers(Set<Marker> newMarkers) async {
  // Filter out markers that are already in the existing markers set
  Set<Marker> uniqueNewMarkers = newMarkers.difference(markers);

  // Add the pickup marker if conditions are met
  if (_pickupLocation != null) {
    uniqueNewMarkers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ),
    );
  }

  // Only update the state if there are new unique markers to add
  if (uniqueNewMarkers.isNotEmpty && mounted) {
    setState(() {
      markers.addAll(uniqueNewMarkers);
    });
  }
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
      "2",
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
      "2",
      goOnline,
    );
  }
  

  Future<void> _loadActiveRideDetails() async {
    int retryCount = 0; // Limit retry attempts
    const maxRetries = 20; // Maximum number of retries
    const retryDelay = Duration(seconds: 1); // Delay between retries

    // Show loading indicator while waiting
    setState(() {
      _rideDetailsText = null; // Set to null to indicate loading
    });

    try {
      while (retryCount < maxRetries) {
        await Future.delayed(retryDelay); // Add delay at the start

        DocumentSnapshot rideDoc = await FirebaseFirestore.instance
            .collection('active_rides')
            .doc(widget.rideId)
            .get();

        if (rideDoc.exists) {
          // Set pickupLocation from the ride document
          _pickupLocation = LatLng(
            rideDoc['pickupLocation']['latitude'],
            rideDoc['pickupLocation']['longitude'],
          );

          if (_pickupLocation == null) {
            print('Error: Failed to load pickup location.');
            return;  // Abort further operations if pickupLocation is not set
          }

          _pickupAddress = await HomePageFunctions.getAddressFromLatLng(_pickupLocation!);

          final dropoffLocationsMap = Map<String, String>.from(rideDoc['dropoffLocations']);
          if (dropoffLocationsMap.isNotEmpty) {
            _dropoffAddresses = dropoffLocationsMap.values.toList();
          }

          // Load participant details
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

          // Ensure setState is called only after data is loaded
          if (mounted) {
            setState(() {
              _rideTime = (rideDoc['timeOfRide'] as Timestamp).toDate();
              _users = userDocs;
              _rideDetailsText = "Pickup: $_pickupAddress";
              _estimatedTime = _calculateEstimatedTime(_rideTime!);
            });

            // Trigger updates only after data is fully loaded
            _updateDirections();
            _fetchOnlineParticipants();
          }
          return; // Exit the loop once data is successfully loaded
        } else {
          retryCount++;
          print('Ride document does not exist. Retrying ($retryCount/$maxRetries)...');
        }
      }

      // If we reach here, the document was not found after max retries
      if (mounted) {
        setState(() {
          _rideDetailsText = 'Failed to load ride details';
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error loading ride details: $e');
        setState(() {
          _rideDetailsText = 'Error loading ride details';
        });
      }
    }
  }






  void _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userProfile = await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _profileImageUrl = userProfile['imageUrl'];
          _username = userProfile['username'];
          _fullName = userProfile['fullName'] ?? 'Shuffl User'; 
          goOnline = userProfile['goOnline'] ?? false;; //changed this line
        });
      }
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

  Future<void> _updateDirections() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('Current user is null');
      return;
    }
    if (currentPosition == null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) {
        print('User document does not exist');
        return;
      }

      var userData = userDoc.data() as Map<String, dynamic>;
      if (userData['lastPickupLocation'] == null || userData['goOnline'] == false) {
        print('Last pickup location is null or user is not online');
        return;
      } else {
        currentPosition = LatLng(userData['lastPickupLocation'].latitude, userData['lastPickupLocation'].longitude);
        print('Current position updated to: $currentPosition');
      }
    }

    if (_pickupLocation == null) {
      print('Pickup location is null');
      return;
    }

    // Draw route for the current user using their current location
    final currentUserRoute = await _getDirections(currentPosition!, _pickupLocation!);
    if (mounted) {
      setState(() {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('current_user_route'),
            points: currentUserRoute,
            color: Colors.yellow, // Different color for the current user's route
            width: 5,
          ),
        );
      });
    }

    // Iterate over each participantId to fetch their lastPickupLocation from Firestore
    for (String participantId in _participantIds) {
      if (participantId == _auth.currentUser?.uid) continue; // Skip the current user

      // Fetch the lastPickupLocation for each participant from Firestore
      DocumentSnapshot participantSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(participantId)
          .get();

      if (participantSnapshot.exists && participantSnapshot['lastPickupLocation'] != null && participantSnapshot['goOnline'] == true) {
        GeoPoint lastPickupLocation = participantSnapshot['lastPickupLocation'];
        LatLng participantLocation = LatLng(lastPickupLocation.latitude, lastPickupLocation.longitude);

        // Fetch and draw the route for the participant from their lastPickupLocation to the ride's pickup location
        final participantRoute = await _getDirections(participantLocation, _pickupLocation!);
        if (mounted) {
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: PolylineId('route_$participantId'),
                points: participantRoute,
                color: Colors.black, // Use black for participant routes
                width: 3,
              ),
            );
          });
        }
      }
    }
  }

  // Function to fetch directions from Google Directions API
  Future<List<LatLng>> _getDirections(LatLng start, LatLng end) async {
    //print('Fetching directions from $start to $end');
    
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$google_maps_api_key';

    try {
      final response = await http.get(Uri.parse(url));
      print('Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('Response body: $jsonResponse');
        
        if (jsonResponse['routes'].isNotEmpty) {
          final route = jsonResponse['routes'][0];
          final overviewPolyline = route['overview_polyline']['points'];
          return _decodePolyline(overviewPolyline);
        } else {
          //print('No routes found in the response');
          throw Exception('No routes found');
        }
      } else {
        //print('Failed to fetch directions. Status code: ${response.statusCode}');
        throw Exception('Failed to fetch directions');
      }
    } catch (e) {
      //print('Exception occurred while fetching directions: $e');
      throw Exception('Error fetching directions: $e');
    }
  }


  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> coordinates = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      coordinates.add(LatLng(
        (lat / 1E5).toDouble(),
        (lng / 1E5).toDouble(),
      ));
    }

    return coordinates;
  }

  void _loadMarkers() {

    // Use the custom pickup icon for pickup location
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation!,
        //icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ),
    );

    // Use the custom dropoff icon for dropoff locations
    // for (var dropoff in widget.dropoffLocations) {
    //   markers.add(
    //     Marker(
    //       markerId: MarkerId(dropoff.toString()),
    //       position: dropoff,
    //       //icon: _dropoffIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    //       infoWindow: const InfoWindow(title: 'Dropoff Location'),
    //     ),
    //   );
    // }

    // Marker for current location
    // if (widget.showCurrentLocation && _currentLocation != null) {
    //   markers.add(
    //     Marker(
    //       markerId: const MarkerId('current'),
    //       position: _currentLocation!,
    //     ),
    //   );
    // }

    if (mounted) {
      setState(() {
        markers = markers;
      });
    }
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
    // Get the current user's ID
    String? currentUserId = _auth.currentUser?.uid;

    if (currentUserId != null) {
      // Get the ride document
      DocumentReference rideDocRef = FirebaseFirestore.instance.collection('active_rides').doc(widget.rideId);

      // Perform a transaction to update the ride data
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get the ride document snapshot
        DocumentSnapshot rideSnapshot = await transaction.get(rideDocRef);

        if (!rideSnapshot.exists) {
          print('Ride document does not exist.');
          return;
        }

        // Update the document:
        // 1. Add the current user to 'endRideParticipants'
        // 2. Keep the current user in 'participants' for rating purposes
        transaction.update(rideDocRef, {
          'endRideParticipants': FieldValue.arrayUnion([currentUserId]),  // Add to new list
        });
      });
    }

    // Log the ride completion
    await FirebaseFirestore.instance.collection('ride_updates').add({
      'rideId': widget.rideId,
      'action': 'ride_completed',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Navigate to the RatingPage with the participants list
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RatingPage(
          rideId: widget.rideId,
          participants: _users.map((e) => e.id).toList(),  // Pass the original participants list
        ),
      ),
    );
  }
}


@override
Widget build(BuildContext context) {
  //final dropoffLocations = _dropoffLocations ?? []; // Assuming _dropoffLocations is initialized elsewhere

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
    // Display loading spinner while data is being fetched
    body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : Column(
            children: [
              if (_pickupLocation != null)
                Expanded(
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: currentPosition ?? _pickupLocation!,
                          zoom: 14,
                        ),
                        markers: markers,
                        polylines: _polylines,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              Row(
                children: [
                  const Text('Go Online', style: TextStyle(color: Colors.black)),
                  Switch(
                    value: goOnline,
                    onChanged: (value) {
                      _toggleGoOnline(value);
                    },
                    activeColor: Colors.yellow,
                    activeTrackColor: Colors.yellowAccent,
                  ),
                ],
              ),
              if (_rideDetailsText != null && _estimatedTime != null)
                RideInfoWidget(
                  rideDetails: _rideDetailsText!,
                  rideTimeText: _getRideTimeText(),
                  dropoffAddresses: _dropoffAddresses,
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
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('End Ride'),
                ),
              ),
            ],
          ),
  );
}
}