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
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/screens/chats_screen/chats_screen.dart';
import 'package:my_flutter_app/screens/edit_preferences/edit_preferences.dart';
import 'package:my_flutter_app/screens/filtered_rides_page/filtered_rides_page.dart';
import 'package:my_flutter_app/screens/location_search_screen/location_search_screen.dart';
import 'package:my_flutter_app/screens/notifications_screen/notifications_screen.dart';
import 'package:my_flutter_app/screens/report_screen/report_screen.dart';
import 'package:my_flutter_app/screens/search_users/search_users.dart';
import 'package:my_flutter_app/screens/tutorial_component_page/tutorial_component_page.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/user_rides_page/user_rides_page.dart';
import 'package:my_flutter_app/screens/waiting_page/waiting_page.dart';
import 'package:my_flutter_app/screens/pdf_viewer/pdf_viewer.dart';

import 'package:my_flutter_app/functions/homepage_functions.dart'; 

import 'package:my_flutter_app/widgets/schedule_ride.dart'; 
import 'package:my_flutter_app/widgets/create_custom_marker.dart'; 



import 'package:http/http.dart' as http;

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
  bool goOnline = false;
  String rideId = '0';
  final LatLng _center = const LatLng(37.8715, -122.2730); // our campus :)
  StreamSubscription<Position>? _positionStreamSubscription;


  Set<Marker> markers = {}; 

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
    HomePageFunctions.fetchOnlineUsers(
      _auth,
      _firestore,
      updateMarkers, // Pass the updateMarkers callback to update the map
      currentPosition,
      markers,
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
      HomePageFunctions.fetchOnlineUsers,
      _positionStreamSubscription,
      markers,
      updateMarkers,
      rideId,
    );
  }

  // Fetch online users and update markers
  void _fetchOnlineUsers() {
    HomePageFunctions.fetchOnlineUsers(
      _auth,
      _firestore,
      updateMarkers,   // Use the callback function for currentPosition
      currentPosition,
      markers,
    );
  }

  void _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userProfile = await _firestore.collection('users').doc(user.uid).get();

      setState(() {
        _profileImageUrl = userProfile['imageUrl'];
        _username = userProfile['username'];
        _fullName = userProfile['fullName'] ?? 'Shuffl User'; 
        goOnline = userProfile['goOnline'] ?? false;
      });

      //await HomePageFunctions.fetchGoOnlineStatus();
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
      Future<bool> isMatch = _validateMatch(doc, timeOfRide);

      if (await isMatch) {
        // Add user to existing ride and update destinations
        await doc.reference.update({
          'participants': FieldValue.arrayUnion([user.uid]),
          'pickupLocations.${user.uid}': finalPickupLocation, // Update pickup locations map
          'dropoffLocations.${user.uid}': finalDropoffLocation, // Update dropoff locations map
          'readyStatus.${user.uid}': false, // Initialize ready status as false for the new participant
        });
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
  // Convert the list of existing drop-offs into LatLng objects (if necessary)
  List<LatLng> dropoffLocations = existingDropoffs;
  const double maxDistance = 160.934; // 100 miles in kilometers

  // We can start with simple checks, e.g., is the new dropoff within an acceptable distance of existing dropoffs?
  // for (LatLng existingDropoff in dropoffLocations) {
  //   double distance = _calculateDistance(existingDropoff, newDropoff);
  //   if (distance > maxDistance) {
  //     return false; // New dropoff is too far from an existing dropoff
  //   }
  // }

  // We can start with simple checks, e.g., is the new dropoff between the first and last dropoff?
  // For simplicity, we can assume that if the new dropoff is within the bounding box of the existing dropoffs,
  // it's a valid addition. A more sophisticated approach could involve actual route planning.

  double minLat = dropoffLocations.map((loc) => loc.latitude).reduce((a, b) => a < b ? a : b);
  double maxLat = dropoffLocations.map((loc) => loc.latitude).reduce((a, b) => a > b ? a : b);
  double minLon = dropoffLocations.map((loc) => loc.longitude).reduce((a, b) => a < b ? a : b);
  double maxLon = dropoffLocations.map((loc) => loc.longitude).reduce((a, b) => a > b ? a : b);

  // Check if the new dropoff is within the bounding box
  if (newDropoff.latitude >= minLat && newDropoff.latitude <= maxLat &&
      newDropoff.longitude >= minLon && newDropoff.longitude <= maxLon) {
    return true;
  }

  // Further checks: If the new dropoff extends the route logically
  // For example, does it follow the direction of the existing route?

  LatLng start = dropoffLocations.first;
  LatLng end = dropoffLocations.last;

  double routeDirectionLat = end.latitude - start.latitude;
  double routeDirectionLon = end.longitude - start.longitude;

  double newDirectionLat = newDropoff.latitude - end.latitude;
  double newDirectionLon = newDropoff.longitude - end.longitude;

  // Basic check if the new direction is somewhat aligned with the route direction
  if (routeDirectionLat * newDirectionLat >= 0 && routeDirectionLon * newDirectionLon >= 0) {
    return true;
  }

  double pickupLat = pickup.latitude;
  double pickupLong = pickup.longitude;

  double dropoffLat = newDropoff.latitude;
  double dropoffLong = newDropoff.longitude;

  // Determine if the dropoff is north or south of the pickup
  bool isDropoffNorth = dropoffLat > pickupLat;

  for (LatLng loc in dropoffLocations) {
    double lat = loc.latitude;
    double long = loc.longitude;

    // Check if the current location is on the same side as the dropoff
    bool isLocNorth = lat > pickupLat;

    if (isLocNorth == isDropoffNorth) {
      print("Location $lat, $long is on the same side as the dropoff.");
    } else {
      print("Location $lat, $long is on the opposite side from the dropoff.");
      return false;
    }
  }

  // If the new dropoff is significantly off the current route, it's not a match
  return false;
}

Future<bool> _validateMatch(DocumentSnapshot rideRequest, DateTime timeOfRide) async {
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
      return false; // If any participant is blocked or has blocked the current user, return false
    }
  }

  // Retrieve the pickup locations and ensure they are LatLng objects
  List<LatLng> pickupLocationsList = [];
  Map<String, String> pickupLocationsMap = Map<String, String>.from(rideRequest['pickupLocations']);

  for (var location in pickupLocationsMap.values) {
    pickupLocationsList.add(await HomePageFunctions.getLatLngFromAddress(location));
  }

  if (pickupLocationsList.isEmpty) return false;

  LatLng currentPickupLocation = await HomePageFunctions.getLatLngFromAddress(_pickupController.text);
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

  LatLng currentDropoffLocation = await HomePageFunctions.getLatLngFromAddress(_dropoffController.text);

  bool isRouteValid = await _isValidRoute(currentPickupLocation, currentDropoffLocation, dropoffLocationsList);

  if (!isRouteValid) {
    return false;
  }

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
            // Use the callback if provided (for the scheduled ride case)
            onSelectAddressCallback(address);
          } else {
            // Otherwise, update the appropriate text controller (for the immediate ride case)
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

void _locationSearchWrapper(bool isPickup, Function(String) onSelectAddressCallback) {
  _navigateToLocationSearch(isPickup, onSelectAddressCallback: onSelectAddressCallback);
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
              MaterialPageRoute(
                builder: (context) => ReportPage(),
              ),
            );
          }
          ),
           ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Tutorial'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
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
          child: TextField(
            controller: _pickupController,
            decoration: InputDecoration(
              hintText: 'Enter pick-up location',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black), 
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black), 
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black), 
              ),
            ),
            style: const TextStyle(color: Colors.black),
            readOnly: true,
            onTap: () => _navigateToLocationSearch(true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _dropoffController,
            decoration: InputDecoration(
              hintText: 'Enter destination',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black), 
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black), 
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black), 
              ),
            ),
            style: const TextStyle(color: Colors.black),
            readOnly: true,
            onTap: () => _navigateToLocationSearch(false),
          ),
        ),Padding(
  padding: const EdgeInsets.all(8.0),
  child: ElevatedButton(
    onPressed: _findRide,
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
      backgroundColor: Colors.yellow,
    ),
    child: const Text('Find Ride Now', style: TextStyle(color: Colors.black)),
  ),
),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 8.0), // Add horizontal padding to match "Find Ride Now" button
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
            minimumSize: const Size(0, 40), // Set a minimum height to match "Find Ride Now" button
          ),
          child: const Text('Schedule Ahead', style: TextStyle(color: Colors.black)),
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
}