import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/ride_group_chats_screen/ride_group_chats_screen.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/screens/active_rides_page/active_rides_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/widgets/loading_widget.dart';

import 'package:my_flutter_app/functions/homepage_functions.dart'; 

import 'package:geolocator/geolocator.dart';
import 'dart:async';


final google_maps_api_key = 'AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk';

class WaitingPage extends StatefulWidget {
  final String rideId;
  const WaitingPage({required this.rideId, Key? key}) : super(key: key);

  @override
  _WaitingPageState createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> {
  late GoogleMapController _mapController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _controller = TextEditingController();
  LatLng? _pickupLocation;
  List<DocumentSnapshot> _users = [];
  List<LatLng> _pickupLocations = [];
  Map<String, bool> _readyStatus = {};
  int _participantsCount = 0;
  LatLng loc = LatLng(0, 0);
  final LatLng _center = const LatLng(37.8715, -122.2730);
  List<LatLng> _dropoffLocations = [];
  DateTime? _rideTime;
  bool _locationsLoaded = false;

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<DocumentSnapshot>? _participantsSubscription;
  LatLng? currentPosition;

  Set<Polyline> _polylines = {};

  String? _profileImageUrl;
  String? _username;
  String? _fullName;

  Set<Marker> markers = {};
  bool goOnline = false;

  List<String> _participantIds = [];     // List for storing participant IDs

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadRideDetails().then((_) {
      // Listen to the current position and update it
      //print('Listening to position updates...');
      HomePageFunctions.determinePosition(
        _auth,
        _firestore,
        updatePosition,
        _positionStreamSubscription,
        markers,
        updateState,
      );
      // print('Listened to position updates. here are the current position: $currentPosition');
      // print('Listening to online participants...');
      _listenToParticipants();
      _listenToReadyStatus();
      _fetchWaitingParticipants();
      // print('Listened to online participants. here are the markers: $markers');
      // print('Loading markers...');
      //_loadMarkers();
      // print('Loaded markers. here are the markers: $markers');
      // print('Updating directions...');
      _updateDirections();
      _createGroupChat();
      _listenToRideStatus();
      // print('Updated directions. here are the polylines: $_polylines');
  });

    // Start listening for online users and update markers in real-time
    // HomePageFunctions.fetchOnlineParticipants(
    //   _auth,
    //   _firestore,
    //   updateMarkers, // Pass the updateMarkers callback to update the map
    //   currentPosition,
    //   markers,
    //   widget.rideId,
    // );

    //_dropoffLocationsFuture = _getDropoffLocations(); // Call this once in initState
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
  if (_pickupLocation != null && goOnline) {
    print('Adding pickup marker at $_pickupLocation');
    newMarkers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ),
    );
  } else {
    print('Pickup location is null or goOnline is false');
  }

  if (mounted) {
    setState(() {
      markers = newMarkers;
      // print('Markers updated: $markers');
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
      "1",
    );
  }

  // Fetch online users and update markers
  void _fetchWaitingParticipants() {
    HomePageFunctions.fetchOnlineParticipants(
      _auth,
      _firestore,
      updateMarkers,   // Use the callback function for currentPosition
      currentPosition,
      markers,
      widget.rideId,
      "1",
    );
  }

  Future<void> _createGroupChat() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    DocumentReference rideDocRef = FirebaseFirestore.instance.collection('rides').doc(widget.rideId);
    DocumentSnapshot rideDoc = await rideDocRef.get();

    if (!rideDoc.exists) {
      print('Ride document does not exist.');
      return;
    }

    List<String> participantUids = List<String>.from(rideDoc['participants']);

    await rideDocRef.collection('groupChat').doc(widget.rideId).set({
      'participants': participantUids,
      'groupTitle': 'Ride Group Chat',
    });
  }

  Future<void> _loadRideDetails() async {
  try {
    DocumentSnapshot rideDoc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .get();

    if (rideDoc.exists) {
      Set<LatLng> pickupLocations = {};
      Set<LatLng> dropoffLocations = {};

      // Populate pickup locations
      Map<String, String> pickupLocationsMap = Map<String, String>.from(rideDoc['pickupLocations']);
      for (var location in pickupLocationsMap.values) {
        pickupLocations.add(await HomePageFunctions.getLatLngFromAddress(location));
      }

      _pickupLocation = _calculateMidpoint(pickupLocations.toList());

      // Populate dropoff locations
      Map<String, String> dropoffLocationsMap = Map<String, String>.from(rideDoc['dropoffLocations']);
      for (var location in dropoffLocationsMap.values) {
        dropoffLocations.add(await HomePageFunctions.getLatLngFromAddress(location));
      }

      // Fetch ready status and participants
      Map<String, bool> readyStatus = Map<String, bool>.from(rideDoc['readyStatus'] ?? {});
      int participantsCount = (rideDoc['participants'] as List).length;
      List<String> userIds = List<String>.from(rideDoc['participants']);
      _participantIds = userIds;
      List<DocumentSnapshot> userDocs = [];

      // Fetch user data for each participant
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

      // Determine the pickup location or default to a center position
      LatLng loc = pickupLocations.isNotEmpty ? pickupLocations.first : _center;

      if (mounted) {
        setState(() {
          _pickupLocations = pickupLocations.toList();
          _dropoffLocations = dropoffLocations.toList();
          _rideTime = (rideDoc['timeOfRide'] as Timestamp).toDate();
          _readyStatus = readyStatus;
          _participantsCount = participantsCount;
          _users = userDocs;
        });

        _loadMarkers(); // Load the markers on the map
        _checkMaxCapacity(rideDoc.reference); // Check the max capacity for the ride
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

void _listenToReadyStatus() {
  _firestore.collection('rides').doc(widget.rideId)
    .snapshots()
    .listen((rideDoc) {
      if (rideDoc.exists) {
        Map<String, bool> newReadyStatus = Map<String, bool>.from(rideDoc['readyStatus'] ?? {});

        if (mounted) {
          setState(() {
            _readyStatus = newReadyStatus;
          });
        }
      }
    });
}

void _listenToRideStatus() {
  _firestore.collection('rides').doc(widget.rideId).snapshots().listen((rideDoc) {
    if (rideDoc.exists && rideDoc['isComplete'] == true) {
      // Navigate to ActiveRidesPage if the ride is marked as complete
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ActiveRidesPage(rideId: widget.rideId),
        ),
      );
    }
  });
}

void _listenToParticipants() {
  _participantsSubscription = _firestore.collection('rides').doc(widget.rideId)
    .snapshots()
    .listen((rideDoc) {
      if (rideDoc.exists) {
        // Fetch new participant list
        List<String> newParticipants = List<String>.from(rideDoc['participants']);
        
        // Reload user profiles for the new participants
        _loadUserProfiles(newParticipants);

        if (mounted) {
          setState(() {
            _participantIds = newParticipants;
          });
        }
      }
    });
}

Future<void> _loadUserProfiles(List<String> participantIds) async {
  List<DocumentSnapshot> userDocs = [];

  for (String uid in participantIds) {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      userDocs.add(userDoc);
    } else {
      print('User with UID $uid not found.');
    }
  }

  if (mounted) {
    setState(() {
      _users = userDocs; // Update the _users list with the newly fetched profiles
    });
  }
}


Future<void> _loadPickupLocations(List<String> participants) async {
  Set<LatLng> pickupLocations = {};
  
  for (String uid in participants) {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      String address = userDoc['pickupLocation'] ?? '';
      LatLng location = await HomePageFunctions.getLatLngFromAddress(address);
      pickupLocations.add(location);
    }
  }

  if (mounted) {
    setState(() {
      _pickupLocations = pickupLocations.toList();
      _pickupLocation = _calculateMidpoint(_pickupLocations);
    });

    _loadMarkers();  // Update the markers on the map with the new locations
  }
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
  //print('Fetching routes for participants: $_participantIds');
  // Iterate over each participantId to fetch their lastPickupLocation from Firestore
  for (String participantId in _participantIds) {
    //print('Fetching route for participant: $participantId');
    if (participantId == _auth.currentUser?.uid) continue; // Skip the current user

    // Fetch the lastPickupLocation for each participant from Firestore
    DocumentSnapshot participantSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(participantId)
        .get();

    if (participantSnapshot.exists && participantSnapshot['lastPickupLocation'] != null && participantSnapshot['goOnline'] == true) {
      print('Fetching route for participant: $participantId');
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


  LatLng _calculateMidpoint(List<LatLng> locations) {
    double latitudeSum = 0;
    double longitudeSum = 0;

    for (LatLng location in locations) {
      latitudeSum += location.latitude;
      longitudeSum += location.longitude;
    }

    double latitudeAverage = latitudeSum / locations.length;
    double longitudeAverage = longitudeSum / locations.length;

    return LatLng(latitudeAverage, longitudeAverage);
  }

  void _navigateToActiveRide(DocumentSnapshot rideDoc) async {
    if (!mounted) return;
    
    DocumentReference activeRideDocRef = FirebaseFirestore.instance
        .collection('active_rides')
        .doc(rideDoc.id);
    
    DocumentSnapshot activeRideDoc = await activeRideDocRef.get();
    
    if (activeRideDoc.exists) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ActiveRidesPage(rideId: rideDoc.id),
        ),
      );
    } else {
      await _initRide(rideDoc.reference);
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (loc != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(loc, 15.0),
      );
    } else {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_center, 15.0),
      );
    }
  }

  void _loadMarkers() {
    print('Loading markers...');
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ),
    );

    if (mounted) {
      setState(() {
        markers = markers;
        print('Markers loaded: $markers');
      });
    }
  }


  Future<void> _checkMaxCapacity(DocumentReference rideDocRef) async {
    try {
      DocumentSnapshot rideDoc = await rideDocRef.get();

      if (!rideDoc.exists) {
        print('Ride document does not exist.');
        return;
      }

      bool isComplete = false;

      for (var userDoc in _users) {
        int maxCapacity = userDoc['preferences']['maxCarCapacity'];
        if (_participantsCount >= maxCapacity) {
          isComplete = true;
          String username = userDoc['username'];
          _showMaxCapacityAlert(username);
          break;
        }
      }

      if (rideDoc.exists) {
        await rideDocRef.update({
          'isComplete': isComplete,
        });
      }
    } catch (e) {
      if (e is FirebaseException && e.code == 'not-found') {
        print('Document not found error: $e');
      } else {
        print('Error updating document: $e');
      }
    }
  }

  void _showMaxCapacityAlert(String username) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Max Capacity Reached", style: TextStyle(color: Colors.black)),
          content: Text(
              "$username's maxCapacity preference is met. The ride is ready to start once everyone is ready.",
              style: TextStyle(color: Colors.black)),
          actions: [
            TextButton(
              child: Text("OK", style: TextStyle(color: Colors.black)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initRide(DocumentReference rideDocRef) async {
    try {
      // Perform the transaction to ensure atomicity
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot rideDoc = await transaction.get(rideDocRef);

        if (!rideDoc.exists) {
          print('Ride document does not exist.');
          return;
        }

        Map<String, dynamic> rideData = rideDoc.data() as Map<String, dynamic>;

        // Check if the ride is already initialized
        if (rideData['status'] == 'active') {
          print('Ride is already active.');
          return;
        }

        // If ride is marked complete but not yet initialized, proceed
        if (rideData['isComplete'] != true) {
          print('Ride is not complete yet.');
          return;
        }

        // Calculate the midpoint of pickup locations
        List<LatLng> pickupLocations = [];
        Map<String, String> pickupLocationsMap = Map<String, String>.from(rideData['pickupLocations']);
        for (var location in pickupLocationsMap.values) {
          pickupLocations.add(await HomePageFunctions.getLatLngFromAddress(location));
        }

        LatLng midpoint = _calculateMidpoint(pickupLocations);
        print('Midpoint: $midpoint');

        // Update the ride's status to 'complete'
        transaction.update(rideDocRef, {'isComplete': true});

        // Prepare the active ride data
        rideData['pickupLocation'] = {
          'latitude': midpoint.latitude,
          'longitude': midpoint.longitude,
        };
        rideData['startTime'] = FieldValue.serverTimestamp();
        rideData['status'] = 'active';
        rideData['endRideParticipants'] = [];  // Initialize the endRideParticipants field

        // Create a reference for the active ride document
        DocumentReference activeRideDocRef = FirebaseFirestore.instance
            .collection('active_rides')
            .doc(rideDocRef.id);

        // Set the active ride document and transfer the group chat messages
        transaction.set(activeRideDocRef, rideData);

        QuerySnapshot messagesSnapshot = await rideDocRef.collection('groupChat').get();
        for (var messageDoc in messagesSnapshot.docs) {
          transaction.set(
            activeRideDocRef.collection('groupChat').doc(messageDoc.id),
            messageDoc.data(),
          );
        }

        // Remove the ride from the 'rides' collection
        transaction.delete(rideDocRef);
      });

      // Navigate to the ActiveRidesPage after initializing the ride
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ActiveRidesPage(rideId: rideDocRef.id),
          ),
        );
      }
    } catch (e) {
      print('Error initializing ride: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start the ride. Please try again.')),
        );
      }
    }
  }


  Future<void> _leaveGroup() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentReference rideDocRef = FirebaseFirestore.instance.collection('rides').doc(widget.rideId);
    DocumentSnapshot rideDoc = await rideDocRef.get();

    if (!rideDoc.exists) {
      print('Ride document does not exist.');
      return;
    }

    await rideDocRef.update({
      'participants': FieldValue.arrayRemove([user.uid]),
      'readyStatus.${user.uid}': FieldValue.delete(),
      'pickupLocations.${user.uid}': FieldValue.delete(),
      'dropoffLocations.${user.uid}': FieldValue.delete(),
    });

    await rideDocRef.collection('groupChat').doc(widget.rideId).update({
    'participants': FieldValue.arrayRemove([user.uid]),
  });

    rideDoc = await rideDocRef.get();
    List<String> participants = List<String>.from(rideDoc['participants']);

    if (participants.isEmpty) {
      await rideDocRef.delete();
    } else {
      int maxCapacity = 0;
      for (String participantId in participants) {
        DocumentSnapshot participantDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(participantId)
            .get();
        int participantMaxCapacity = participantDoc['preferences']['maxCarCapacity'];
        maxCapacity = maxCapacity > participantMaxCapacity
            ? maxCapacity
            : participantMaxCapacity;
      }

      if (participants.length >= maxCapacity) {
        await rideDocRef.update({'isComplete': true});
      } else {
        await rideDocRef.update({'isComplete': false});
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    }
    Future<void> _createGroupChat() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    DocumentReference rideDocRef = FirebaseFirestore.instance.collection('rides').doc(widget.rideId);
    DocumentSnapshot rideDoc = await rideDocRef.get();

    if (!rideDoc.exists) {
      print('Ride document does not exist.');
      return;
    }

    List<String> participantUids = List<String>.from(rideDoc['participants']);

    await rideDocRef.collection('groupChat').doc(widget.rideId).set({
      'participants': participantUids,
      'groupTitle': 'Ride Group Chat',
    });
  }
}


// Function to fetch directions from Google Directions API
Future<List<LatLng>> _getDirections(LatLng start, LatLng end) async {
  print('Fetching directions from $start to $end');
  
  final url =
      'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$google_maps_api_key';

  try {
    final response = await http.get(Uri.parse(url));
    //print('Response status code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      print('Directions fetched successfully');
      final jsonResponse = json.decode(response.body);
      //print('Response body: $jsonResponse');
      
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

Future<void> _toggleReadyStatus(String userId) async {
  if (userId != _auth.currentUser?.uid) return;

  DocumentReference rideDocRef = FirebaseFirestore.instance.collection('rides').doc(widget.rideId);
  
  bool shouldInitRide = false;

  await FirebaseFirestore.instance.runTransaction((transaction) async {
    DocumentSnapshot rideDoc = await transaction.get(rideDocRef);

    if (!rideDoc.exists) {
      print('Ride document does not exist.');
      return;
    }

    Map<String, dynamic> data = rideDoc.data() as Map<String, dynamic>;
    Map<String, bool> readyStatus = Map<String, bool>.from(data['readyStatus'] ?? {});
    List<dynamic> participants = data['participants'];

    bool currentStatus = readyStatus[userId] ?? false;
    readyStatus[userId] = !currentStatus;  // Toggle the ready status

    transaction.update(rideDocRef, {'readyStatus': readyStatus});

    if (readyStatus.values.every((status) => status) && participants.length > 1) {
      transaction.update(rideDocRef, {'isComplete': true});
      shouldInitRide = true;
    }
  });

  // If all participants are ready, initiate the ride
  if (shouldInitRide) {
    await _initRide(rideDocRef);
  }

  // Ensure the UI updates (alp fix)
  if (mounted) {
    setState(() {
      _readyStatus[userId] = !_readyStatus[userId]!;
    });
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

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: kBackgroundColor,
    appBar: AppBar(
      title: const Text(
        'Waiting Page',
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
                  isActiveRide: false,
                ),
              ),
            );
          },
        ),
      ],
    ),
    body: _users.isEmpty
        ? const Center(
            child: LoadingWidget(logoPath: 'assets/icons/ShuffleLogo.jpeg'),
          )
        : Column(
            children: [
              SizedBox(
                height: 300,  // Add a specific height to avoid infinite size errors
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: currentPosition ?? _pickupLocation!,
                    zoom: 14,
                  ),
                  markers: markers, // Combine markers and participantMarkers
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                ),
              ),
              const Text('Go Online', style: TextStyle(color: Colors.black)),
                Switch(
                  value: goOnline,
                  onChanged: (value) {
                    _toggleGoOnline(value);
                  },
                  activeColor: Colors.yellow, 
                  activeTrackColor: Colors.yellowAccent, 
                ),
              if (_rideTime != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Ride Time: ${DateFormat('yyyy-MM-dd – kk:mm').format(_rideTime!)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    var user = _users[index];
                    var username = user['username'] ?? '';
                    var fullName = user['fullName'] ?? '';
                    var imageUrl = user.data().toString().contains('imageUrl')
                        ? user['imageUrl']
                        : null;
                    bool isReady = _readyStatus[user.id] ?? false;
                    bool isCurrentUser = user.id == _auth.currentUser?.uid;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      child: ListTile(
                        onTap: () {
                          if (isCurrentUser) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => UserProfile()),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ViewUserProfile(uid: user.id)),
                            );
                          }
                        },
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
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
                        trailing: ElevatedButton(
                          onPressed: isCurrentUser ? () => _toggleReadyStatus(user.id) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isReady ? Colors.green : Colors.grey[300],
                            foregroundColor: isReady ? Colors.white : Colors.black,
                            disabledBackgroundColor: isReady ? Colors.green : Colors.grey[300],
                            disabledForegroundColor: isReady ? Colors.white : Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18.0),
                            ),
                            side: BorderSide(color: isReady ? Colors.green : Colors.grey),
                          ),
                          child: Text(isCurrentUser
                            ? (isReady ? 'Unready' : 'Ready Up')
                            : (isReady ? 'Ready' : 'Unready')),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: _leaveGroup,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  child: const Text(
                    'Leave Group',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
  );
}

  // Move async logic outside the build method
  Future<void> _loadPickupAndDropoffLocations(DocumentSnapshot rideDoc) async {
    List<String> pickupAddresses = List<String>.from(rideDoc['pickupLocations'].values);
    List<String> dropoffAddresses = List<String>.from(rideDoc['dropoffLocations'].values);

    // Resolve the pickup and dropoff locations asynchronously
    _pickupLocations = await Future.wait(pickupAddresses.map((address) => HomePageFunctions.getLatLngFromAddress(address)).toList());
    _dropoffLocations = await Future.wait(dropoffAddresses.map((address) => HomePageFunctions.getLatLngFromAddress(address)).toList());

    _rideTime = (rideDoc['timeOfRide'] as Timestamp).toDate();

    if (mounted) {
      setState(() {});
    }
  }
} 