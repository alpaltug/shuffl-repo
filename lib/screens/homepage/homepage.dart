import 'dart:convert';
import 'dart:math';
import 'dart:async';

import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/main.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:my_flutter_app/widgets/invite_button_widget.dart';


import 'package:my_flutter_app/screens/invite_contacts_screen/invite_contacts_screen.dart';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/screens/chats_screen/chats_screen.dart';
import 'package:my_flutter_app/screens/edit_preferences/edit_preferences.dart';
import 'package:my_flutter_app/screens/filtered_rides_page/filtered_rides_page.dart';
import 'package:my_flutter_app/screens/location_search_screen/location_search_screen.dart';
import 'package:my_flutter_app/screens/notifications_screen/notifications_screen.dart';
import 'package:my_flutter_app/screens/refer_friend_screen/refer_friend_screen.dart';
import 'package:my_flutter_app/screens/report_screen/report_screen.dart';
import 'package:my_flutter_app/screens/search_users/search_users.dart';
import 'package:my_flutter_app/screens/tutorial_component_page/tutorial_component_page.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/user_rides_page/user_rides_page.dart';
import 'package:my_flutter_app/screens/waiting_page/waiting_page.dart';
import 'package:my_flutter_app/screens/pdf_viewer/pdf_viewer.dart';
import 'package:my_flutter_app/services/notification_service.dart';
import 'package:my_flutter_app/screens/enter_referral_code/enter_referral_code_screen.dart';



import 'package:my_flutter_app/widgets/find_ride_widget.dart';



import 'package:my_flutter_app/functions/homepage_functions.dart'; 

import 'package:my_flutter_app/widgets/schedule_ride.dart'; 
import 'package:my_flutter_app/widgets/create_custom_marker.dart'; 



import 'package:http/http.dart' as http;


import 'package:flutter/cupertino.dart';





final google_maps_api_key = 'AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk';



class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  late GoogleMapController mapController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  String? _profileImageUrl;
  String? _username;
  String? _fullName;
  LatLng? currentPosition;
  DateTime? _selectedRideTime;
  String? _selectedPickupLocation;
  int _uniqueMessageSenderCount = 0;
  String goOnline = 'offline'; // Default value
  String rideId = '0';
  final LatLng _center = const LatLng(37.8715, -122.2730); // our campus :)
  StreamSubscription<Position>? _positionStreamSubscription;
  final _notificationService = NotificationService();

  final InviteButtonWidget _inviteButton = InviteButtonWidget();

  Map<String, DateTime> markerTimestamps = {}; // To track the last update time for each marker


  Set<Marker> markers = {}; 

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadVisibilityOption();

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
    HomePageFunctions.fetchOnlineUsers(
      _auth,
      _firestore,
      updateMarkers, // Pass the updateMarkers callback to update the map
      currentPosition,
      markers,
      goOnline,
    );

    _listenToUnreadMessageSenderCount();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute<dynamic>);
  }

  @override
  void didPopNext() {
    _loadUserProfile();
    _getUniqueUnreadMessageSenderCount();
  }

  // Callback to update 'goOnline' state
  void updateGoOnlineState(String newGoOnline) {
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
  void updateMarkers(Set<Marker> newMarkers) async {
    if (mounted) {
      print('Updating markers for markers with length: ${newMarkers.length}');
      setState(() {
        // Calculate markers to remove (present in markers but not in newMarkers)
        Set<Marker> markersToRemove = markers.difference(newMarkers);

        // Calculate markers to add (present in newMarkers but not in markers)
        Set<Marker> markersToAdd = newMarkers.difference(markers);

        // Remove old markers
        markers.removeAll(markersToRemove);

        // Add new markers
        markers.addAll(markersToAdd);
      });
    }
  }

  void _loadVisibilityOption() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userProfile = await _firestore.collection('users').doc(user.uid).get();
      if (userProfile.exists) {
        setState(() {
          goOnline = userProfile['goOnline'] ?? 'offline';
        });
      }
    }
  }

  // Toggle 'goOnline' and update necessary state variables
  Future<void> _toggleGoOnline(String value) async {
    goOnline = value;
    await HomePageFunctions.toggleVisibilityOption(
      value,
      currentPosition,
      _auth,
      _firestore,
      updateState,          // Use the callback function for setState
      updatePosition,        // Use the callback function for currentPosition
      updateGoOnlineState,   // Use the callback function for goOnline state
      HomePageFunctions.fetchOnlineUsers,
      _positionStreamSubscription,
      markers,
      updateMarkers,
      "0",
      "0",
    );
  }

  // Fetch online users and update markers
  Future<void> _fetchOnlineUsers() async {
    await HomePageFunctions.fetchOnlineUsers(
      _auth,
      _firestore,
      updateMarkers,   // Use the callback function for currentPosition
      currentPosition,
      markers,
      goOnline,
    );
  }

  void _loadUserProfile() async {
    User? user = _auth.currentUser;
    LatLng defaultPosition = LatLng(37.8715, -122.2730); // Default to Berkeley

    if (user != null) {
      DocumentSnapshot userProfile = await _firestore.collection('users').doc(user.uid).get();

      // Access the data map from the document snapshot
      Map<String, dynamic>? data = userProfile.data() as Map<String, dynamic>?;

      if (userProfile.exists && data != null && data.containsKey('lastPickupLocation') && data['lastPickupLocation'] != null) {
        // Fetch position from Firestore
        GeoPoint geoPoint = data['lastPickupLocation'];
        currentPosition = LatLng(geoPoint.latitude, geoPoint.longitude);
      } else {
        try {
          // Get user's current position
          Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          currentPosition = LatLng(position.latitude, position.longitude);

          // Save to Firestore
          await _firestore.collection('users').doc(user.uid).update({
            'lastPickupLocation': GeoPoint(position.latitude, position.longitude),
          });
        } catch (e) {
          // Use default position if unable to get current location
          currentPosition = defaultPosition;
        }
      }

      setState(() {
        _profileImageUrl = data?['imageUrl'];
        _username = data?['username'];
        _fullName = data?['fullName'] ?? 'Shuffl User'; 
      });
    } else {
      // Use default position if user is null
      setState(() {
        currentPosition = defaultPosition;
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(currentPosition!, 15.0),
      );
    } else {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_center, 15.0), // Default to Berkeley if no location
      );
    }
  }

  Future<void> _showDateTimePicker() async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      TimeOfDay? selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime != null) {
        _selectedRideTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );
      }
    }
  }

  Future<void> _scheduleRide() async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      TimeOfDay? selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime != null) {
        DateTime selectedDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        // Initialize variables for pickup and dropoff locations
        String? pickupLocation;
        String? dropoffLocation;

        // Prompt the user to select pickup location
        _navigateToLocationSearch(true, onSelectAddressCallback: (pickupAddress) {
          pickupLocation = pickupAddress;

          // After pickup is selected, prompt the user to select dropoff location
          _navigateToLocationSearch(false, onSelectAddressCallback: (dropoffAddress) {
            dropoffLocation = dropoffAddress;

            // Proceed with ride finding logic only after both locations are selected
            if (pickupLocation != null && dropoffLocation != null) {
              _findRideAtScheduledTime(
                timeOfRide: selectedDateTime,
                pickupLocation: pickupLocation!,
                dropoffLocation: dropoffLocation!,
              );
            } else {
              // Handle case where user cancels location selection
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select both pickup and dropoff locations.')),
              );
            }
          });
        });
      }
    }
  }


Future<void> _findRideAtScheduledTime({
    required DateTime timeOfRide,
    required String pickupLocation,
    required String dropoffLocation,
  }) async {
    String rideId = await _createRideRequest(
      timeOfRide,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
    );

    // Push the user to the waiting page for the newly joined or created ride request
    if (rideId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingPage(rideId: rideId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create or join a ride.')),
      );
    }
  }


Future<String> _createRideRequest(DateTime timeOfRide, {String? pickupLocation, String? dropoffLocation}) async {
  User? user = _auth.currentUser;
  if (user == null) return '';

  // Determine the pickup and dropoff locations to use
  String finalPickupLocation = pickupLocation ?? _pickupController.text;
  String finalDropoffLocation = dropoffLocation ?? _dropoffController.text;

  // Query ride requests with the same time of ride within a certain range (e.g., +/- 15 minutes)
  QuerySnapshot existingRides = await _firestore
      .collection('rides')
      .where('timeOfRide', isGreaterThanOrEqualTo: timeOfRide.subtract(const Duration(minutes: 15)))
      .where('timeOfRide', isLessThanOrEqualTo: timeOfRide.add(const Duration(minutes: 15)))
      .get();

  bool matched = false;
  String rideId = '';

  for (var doc in existingRides.docs) {
    // Pass the final pickup and dropoff locations to the _validateMatch function
    Future<bool> isMatch = _validateMatch(doc, timeOfRide, finalPickupLocation, finalDropoffLocation);

    if (await isMatch) {
      // Add user to existing ride and update destinations
      await doc.reference.update({
        'participants': FieldValue.arrayUnion([user.uid]),
        'pickupLocations.${user.uid}': finalPickupLocation, // Update pickup locations map
        'dropoffLocations.${user.uid}': finalDropoffLocation, // Update dropoff locations map
        'readyStatus.${user.uid}': false, // Initialize ready status as false for the new participant
      });
      await _sendNewParticipantNotification(doc.id, user.uid);
      matched = true;
      rideId = doc.id;
      break;
    }
  }

  if (!matched) {
    // Create a new ride request if no match was found
    DocumentReference newRide = await _firestore.collection('rides').add({
      'timeOfRide': timeOfRide,
      'pickupLocations': {user.uid: finalPickupLocation}, // Store pickup locations as a map
      'dropoffLocations': {user.uid: finalDropoffLocation}, // Store dropoff locations as a map
      'participants': [user.uid],
      'isComplete': false,
      'timestamp': FieldValue.serverTimestamp(),
      'readyStatus': {user.uid: false}, // Initialize ready status map with current user as false
    });

    rideId = newRide.id;
  }

  // Reset the selected ride time after the request
  _selectedRideTime = null;

  return rideId;
}



Future<bool> _isValidRoute(LatLng pickup, LatLng newDropoff, List<LatLng> existingDropoffs) async {
  print('Validating route with pickup: $pickup, newDropoff: $newDropoff, existingDropoffs: $existingDropoffs');
  
  List<LatLng> dropoffLocations = existingDropoffs;
  const double maxDistance = 160.934; // 100 miles in kilometers
  
  // Simple bounding box check
  double minLat = dropoffLocations.map((loc) => loc.latitude).reduce((a, b) => a < b ? a : b);
  double maxLat = dropoffLocations.map((loc) => loc.latitude).reduce((a, b) => a > b ? a : b);
  double minLon = dropoffLocations.map((loc) => loc.longitude).reduce((a, b) => a < b ? a : b);
  double maxLon = dropoffLocations.map((loc) => loc.longitude).reduce((a, b) => a > b ? a : b);

  print('Bounding box calculated: minLat: $minLat, maxLat: $maxLat, minLon: $minLon, maxLon: $maxLon');
  
  if (newDropoff.latitude >= minLat && newDropoff.latitude <= maxLat &&
      newDropoff.longitude >= minLon && newDropoff.longitude <= maxLon) {
    print('New dropoff is within the bounding box');
    return true;
  }

  // Step 1: Compute the initial route with existing dropoffs
  List<LatLng> allStops = [pickup, ...existingDropoffs];
  print('Original route: $allStops');
  
  // Step 2: Compute route with new dropoff added
  List<LatLng> routeWithNewDropoff = [pickup, ...existingDropoffs, newDropoff];
  print('Route with new dropoff: $routeWithNewDropoff');

  // Step 3: Fetch routes from Google Directions API
  double originalRouteDistance = await _getRouteDistance(allStops);
  double newRouteDistance = await _getRouteDistance(routeWithNewDropoff);
  
  print('Original route distance: $originalRouteDistance, New route distance: $newRouteDistance');

  // Step 4: Decide based on the percentage increase in route distance
  const double maxAllowedIncrease = 0.2; // Allow only a 20% increase in route distance
  if (newRouteDistance <= originalRouteDistance * (1 + maxAllowedIncrease)) {
    print('Route is valid, distance increase is within allowed range.');
    return true;
  }
  
  print('Failed to validate route with pickup: $pickup, existing dropoffs: $existingDropoffs');
  return false;
}


Future<double> _getRouteDistance(List<LatLng> waypoints) async {
  String origin = '${waypoints.first.latitude},${waypoints.first.longitude}';
  String destination = '${waypoints.last.latitude},${waypoints.last.longitude}';
  
  // Add `optimize:true` to the waypoints parameter
  String waypointsParam = 'optimize:true|' + waypoints.sublist(1, waypoints.length - 1)
      .map((latLng) => '${latLng.latitude},${latLng.longitude}')
      .join('|');

  String url =
      'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&waypoints=$waypointsParam&key=$google_maps_api_key';

  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['routes'] != null && data['routes'].isNotEmpty) {
      return data['routes'][0]['legs']
          .map<double>((leg) {
            var distanceValue = leg['distance']['value'];
            if (distanceValue != null && distanceValue is num) {
              return distanceValue.toDouble(); // Ensure it is treated as a double
            }
            return 0.0; // Handle cases where distance might be missing or invalid
          })
          .fold(0.0, (sum, value) => sum + value); // Sum of all leg distances using fold
    }
  }

  throw Exception('Failed to fetch directions');
}



Future<bool> _validateMatch(DocumentSnapshot rideRequest, DateTime timeOfRide, String pickupLocation, String dropoffLocation) async {
  User? currentUser = _auth.currentUser;
  if (currentUser == null) return false;

  // Retrieve the current user data
  DocumentSnapshot currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
  if (!currentUserDoc.exists) return false;

  Map<String, dynamic> currentUserData = currentUserDoc.data() as Map<String, dynamic>;
  List<String> blockedUsers = List<String>.from(currentUserData['blockedUsers'] ?? []);
  List<String> blockedBy = List<String>.from(currentUserData['blockedBy'] ?? []);

  List<String> participants = List<String>.from(rideRequest['participants']);
  int currentGroupSize = participants.length;

  // Check for blocked users within the ride participants
  for (String participantId in participants) {
    if (blockedUsers.contains(participantId) || blockedBy.contains(participantId)) {
      return false;
    }
  }

  // Retrieve the pickup and dropoff locations and ensure they are LatLng objects
  List<LatLng> pickupLocationsList = [];
  Map<String, String> pickupLocationsMap = Map<String, String>.from(rideRequest['pickupLocations']);

  for (var location in pickupLocationsMap.values) {
    pickupLocationsList.add(await HomePageFunctions.getLatLngFromAddress(location));
  }

  if (pickupLocationsList.isEmpty) return false;

  // Use the provided pickup location for the user instead of _pickupController.text
  LatLng currentPickupLocation = await HomePageFunctions.getLatLngFromAddress(pickupLocation);
  bool pickupProximityMatched = pickupLocationsList.any((location) =>
      HomePageFunctions.isWithinProximity(location, currentPickupLocation));

  if (!pickupProximityMatched) {
    return false;
  }

  // Retrieve the dropoff locations and ensure they are LatLng objects
  List<LatLng> dropoffLocationsList = [];
  Map<String, String> dropoffLocationsMap = Map<String, String>.from(rideRequest['dropoffLocations']);
  for (var location in dropoffLocationsMap.values) {
    dropoffLocationsList.add(await HomePageFunctions.getLatLngFromAddress(location));
  }

  if (dropoffLocationsList.isEmpty) return false;

  // Use the provided dropoff location for the user instead of _dropoffController.text
  LatLng currentDropoffLocation = await HomePageFunctions.getLatLngFromAddress(dropoffLocation);

  bool isRouteValid = await _isValidRoute(currentPickupLocation, currentDropoffLocation, dropoffLocationsList);

  if (!isRouteValid) {
    return false;
  }

  // Validate preferences and return result
  for (String participantId in participants) {
    if (participantId == currentUser.uid) continue;

    DocumentSnapshot participantDoc = await _firestore.collection('users').doc(participantId).get();
    if (!participantDoc.exists) return false;

    Map<String, dynamic> participantData = participantDoc.data() as Map<String, dynamic>;

    if (!HomePageFunctions.doesUserMatchPreferences(currentUserData, participantData, currentGroupSize) ||
        !HomePageFunctions.doesUserDataMatchPreferences(participantData, currentUserData, currentGroupSize)) {
      return false;
    }
  }

  return true;
}


Future<void> _showDateTimeAndLocationPicker() async {
  DateTime? selectedDate = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
  );

  if (selectedDate != null) {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime != null) {
      DateTime selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      // Initialize variables for pickup and dropoff locations
      String? pickupLocation;
      String? dropoffLocation;

      // Prompt the user to select the pickup location
      _navigateToLocationSearch(true, onSelectAddressCallback: (pickupAddress) {
        pickupLocation = pickupAddress;

        // After pickup is selected, prompt the user to select the dropoff location
        _navigateToLocationSearch(false, onSelectAddressCallback: (dropoffAddress) {
          dropoffLocation = dropoffAddress;

          // Proceed with ride finding logic only after both locations are selected
          if (pickupLocation != null && dropoffLocation != null) {
            _findRideAtScheduledTime(
              timeOfRide: selectedDateTime,
              pickupLocation: pickupLocation!,
              dropoffLocation: dropoffLocation!,
            );
          } else {
            // Handle case where user cancels location selection
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select both pickup and dropoff locations.')),
            );
          }
        });
      });
    }
  }
}


void _navigateToLocationSearch(bool isPickup, {Function(String)? onSelectAddressCallback}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => LocationSearchScreen(
        isPickup: isPickup,
        currentPosition: currentPosition,
        onSelectAddress: (address) {
          if (onSelectAddressCallback != null) {
            onSelectAddressCallback(address);
          } else {
            if (isPickup) {
              _pickupController.text = address;
            } else {
              _dropoffController.text = address;
            }
          }
        },
      ),
    ),
  );
}

void _scheduleRideWrapper(DateTime timeOfRide, String pickupLocation, String dropoffLocation) {
  _findRideAtScheduledTime(
    timeOfRide: timeOfRide,
    pickupLocation: pickupLocation,
    dropoffLocation: dropoffLocation,
  );
}

void _findRideWithLocations(String pickupLocation, String dropoffLocation) {
  _findRideAtScheduledTime(
    timeOfRide: DateTime.now(),
    pickupLocation: pickupLocation,
    dropoffLocation: dropoffLocation,
  );
}


void _locationSearchWrapper(bool isPickup, Function(String) onSelectAddressCallback) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => LocationSearchScreen(
        isPickup: isPickup,
        currentPosition: currentPosition,
        onSelectAddress: (address) {
          onSelectAddressCallback(address);
        },
      ),
    ),
  );
}

void _findRide() async {
  if (_pickupController.text.isNotEmpty && _dropoffController.text.isNotEmpty) {
    DateTime rideTime = _selectedRideTime ?? DateTime.now(); // Use selected time or current time
    String rideId = await _createRideRequest(rideTime);

    // Push the user to the waiting page for the newly joined or created ride request
    if (rideId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WaitingPage(rideId: rideId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create or join a ride.')),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select both pickup and dropoff locations.')),
    );
  }
}


Stream<int> _getNotificationCountStream() {
  User? user = _auth.currentUser;
  if (user != null) {
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  return Stream.value(0);
}


void _listenToUnreadMessageSenderCount() {
  User? currentUser = _auth.currentUser;
  if (currentUser != null) {
    _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('chats')
        .snapshots()
        .listen((snapshot) {
      _getUniqueUnreadMessageSenderCount();
    });
  }
}


Future<void> _getUniqueUnreadMessageSenderCount() async {
  User? currentUser = _auth.currentUser;
  if (currentUser != null) {
    int count = await _firestoreService.getUnreadMessageSenderCount(currentUser.uid);
    setState(() {
      _uniqueMessageSenderCount = count;
    });
  }
}

Future<void> _sendNewParticipantNotification(String rideId, String newParticipantId) async {
  User? currentUser = _auth.currentUser;
  if (currentUser == null) return;
  
  DocumentSnapshot rideDoc = await _firestore.collection('rides').doc(rideId).get();
  if (!rideDoc.exists) return;

  List<String> participants = List<String>.from(rideDoc['participants']);
  participants.remove(newParticipantId);

  DocumentSnapshot newUserDoc = await _firestore.collection('users').doc(newParticipantId).get();
  String newUsername = newUserDoc['username'] ?? 'A user';

  Map<String, dynamic> dropoffLocationsMap = Map<String, dynamic>.from(rideDoc['dropoffLocations']);
  String dropoffLocation = dropoffLocationsMap[newParticipantId] ?? 'Unknown Location';

  for (String participantId in participants) {
    await _firestore.collection('users').doc(participantId).collection('notifications').add({
      'type': 'new_participant',
      'rideId': rideId,
      'newUsername': newUsername,
      'newUid': newParticipantId,
      'dropoffLocation': dropoffLocation,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(_fullName != null ? 'Hi, $_fullName!' : 'Hi, Shuffl User!'),
      backgroundColor: kBackgroundColor,
      actions: [
        StreamBuilder<int>(
          stream: _getNotificationCountStream(),
          builder: (context, snapshot) {
            int notificationCount = snapshot.data ?? 0;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                    );
                  },
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: 11,
                    top: 11,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatsScreen()),
                );
              },
            ),
            if (_uniqueMessageSenderCount > 0)
              Positioned(
                right: 11,
                top: 11,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Text(
                    '$_uniqueMessageSenderCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        // Invite Friends Icon
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'Invite Friends',
          onPressed: () => _inviteButton.sendInvitations(context),
        ),
      ],
    ),
    drawer: Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: const BoxDecoration(
              color: kBackgroundColor,
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserProfile()),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? NetworkImage(_profileImageUrl!)
                        : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _username ?? 'Unknown User',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search Users'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchUsers()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Edit Preferences'),
            onTap: () {
              User? user = _auth.currentUser;
              if (user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditPreferencesPage(uid: user.uid)),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_car),
            title: const Text('Ride Marketplace'),
            onTap: () {
              User? user = _auth.currentUser;
              if (user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FilteredRidesPage()),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('My Rides'),
            onTap: () {
              User? user = _auth.currentUser;
              if (user != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UserRidesPage()),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.card_giftcard),
            title: const Text('Referral Codes'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EnterReferralCodeScreen()),
              );
            },
          ),
          // ListTile(
          //   leading: const Icon(Icons.person_add),
          //   title: const Text('Refer a Friend'),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       CupertinoPageRoute(builder: (context) => const ReferFriendScreen()),
          //     );
          //   },
          // ),
          // ListTile(
          //   leading: const Icon(Icons.contacts),
          //   title: const Text('Invite Contacts'),
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       CupertinoPageRoute(builder: (context) => InviteContactsScreen()),
          //     );
          //   },
          // ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewerPage(
                    pdfAssetPath: 'assets/Shuffl Privacy Policy Aug 2024.pdf',
                    title: 'Privacy Policy',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Use'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PDFViewerPage(
                    pdfAssetPath: 'assets/Shuffl mobility Terms of Use.pdf',
                    title: 'Terms of Use',
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.report),
            title: const Text('Report'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ReportPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.school),
            title: const Text('Tutorial'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return const TutorialComponent();
                },
              );
            },
          ),
        ],
      ),
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => ScheduleRideWidget(
                        onScheduleRide: _scheduleRideWrapper,
                        onLocationSearch: _locationSearchWrapper,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Schedule Ahead', style: TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => RideWidget(
                        onSubmit: _findRideWithLocations,
                        onLocationSearch: _locationSearchWrapper,
                        isJoinRide: false,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text('Find Ride Now', style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Visibility Options', style: TextStyle(color: CupertinoColors.black)),
              CupertinoButton(
                child: Text(
                  goOnline,
                  style: const TextStyle(color: CupertinoColors.activeBlue),
                ),
                onPressed: () async {
                  final selectedOption = await showCupertinoModalPopup<String>(
                    context: context,
                    builder: (BuildContext context) {
                      return CupertinoActionSheet(
                        title: const Text('Select Visibility Option'),
                        actions: <CupertinoActionSheetAction>[
                          CupertinoActionSheetAction(
                            child: const Text('Everyone'),
                            onPressed: () {
                              Navigator.pop(context, 'everyone');
                            },
                          ),
                          CupertinoActionSheetAction(
                            child: const Text('Friends'),
                            onPressed: () {
                              Navigator.pop(context, 'friends');
                            },
                          ),
                          CupertinoActionSheetAction(
                            child: const Text('Tags'),
                            onPressed: () {
                              Navigator.pop(context, 'tags');
                            },
                          ),
                          CupertinoActionSheetAction(
                            child: const Text('Offline'),
                            onPressed: () {
                              Navigator.pop(context, 'offline');
                            },
                          ),
                          CupertinoActionSheetAction(
                            child: const Text('Friend and Tags'),
                            onPressed: () {
                              Navigator.pop(context, 'friend_and_tags');
                            },
                          ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          child: const Text('Cancel'),
                          onPressed: () {
                            Navigator.pop(context, null);
                          },
                        ),
                      );
                    },
                  );

                  if (selectedOption != null) {
                    setState(() {
                      goOnline = selectedOption;
                    });
                    await _toggleGoOnline(selectedOption);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: currentPosition ?? _center,
                  zoom: 15.0,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                markers: markers,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// Define updateVisibilityOption method
void updateVisibilityOption(String newVisibilityOption) {
  setState(() {
    goOnline = newVisibilityOption;
  });
}

// Define fetchOnlineUsers method
void fetchOnlineUsers(
  FirebaseAuth auth,
  FirebaseFirestore firestore,
  Function(Set<Marker>) updateMarkers,
  LatLng currentPosition,
  Set<Marker> markers,
  String visibilityOption,
) {
  HomePageFunctions.fetchOnlineUsers(
    auth,
    firestore,
    updateMarkers,
    currentPosition,
    markers,
    visibilityOption,
  );
}

}