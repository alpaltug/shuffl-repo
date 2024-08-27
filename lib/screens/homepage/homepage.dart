import 'dart:convert';
import 'dart:math';
import 'package:my_flutter_app/main.dart';



import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
import 'package:my_flutter_app/screens/search_users/search_users.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/user_rides_page/user_rides_page.dart';
import 'package:my_flutter_app/screens/waiting_page/waiting_page.dart';
import 'package:my_flutter_app/screens/active_rides_page/active_rides_page.dart';
import 'package:my_flutter_app/screens/pdf_viewer/pdf_viewer.dart';

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
  LatLng? _currentPosition;
  DateTime? _selectedRideTime;
  int _uniqueMessageSenderCount = 0;
  bool _goOnline = false;
  final LatLng _center = const LatLng(37.8715, -122.2730); // our campus :)

  Set<Marker> _markers = {}; // Store markers

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _determinePosition();
    _listenToUnreadMessageSenderCount();
    _fetchOnlineUsers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute<dynamic>);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadUserProfile();
    _getUniqueUnreadMessageSenderCount();
  }

  void _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userProfile = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _profileImageUrl = userProfile['imageUrl'];
        _username = userProfile['username'];
        _goOnline = userProfile['goOnline'] ?? false;
      });
    }
  }

  Future<void> _toggleGoOnline(bool value) async {  
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'goOnline': value,
      });

      setState(() {
        _goOnline = value;
      });

      if (value) {
        await _determinePosition();  
      }

      _fetchOnlineUsers();
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

  Future<void> _determinePosition() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    LatLng currentPosition = LatLng(position.latitude, position.longitude);
    String address = await _getAddressFromLatLng(currentPosition);

    setState(() {
      _currentPosition = currentPosition;
      _pickupController.text = address;
      _addCurrentLocationMarker();
    });

    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(currentPosition, 15.0),
    );

    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'lastPickupLocation': GeoPoint(currentPosition.latitude, currentPosition.longitude),
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
  mapController = controller;
  if (_currentPosition != null) {
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
    );
  } else {
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(_center, 15.0), // Default to Berkeley if no location
    );
  }
}

  void _addCurrentLocationMarker() {
    if (_currentPosition != null) {
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId("current_location"),
            position: _currentPosition!,
            infoWindow: const InfoWindow(title: "You're here"),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      });
    }
  }

  Future<void> _fetchOnlineUsers() async {
  User? currentUser = _auth.currentUser;
  if (currentUser == null) return;

  Stream<QuerySnapshot> _getOnlineUsersStream() {
    return _firestore.collection('users').where('goOnline', isEqualTo: true).snapshots();
  }

  _getOnlineUsersStream().listen((QuerySnapshot userSnapshot) {
    Set<Marker> markers = {};
    Map<String, int> locationCount = {};

    for (var doc in userSnapshot.docs) {
      var userData = doc.data() as Map<String, dynamic>;

      if (userData.containsKey('lastPickupLocation')) {
        GeoPoint location = userData['lastPickupLocation'];
        String locationKey = '${location.latitude},${location.longitude}';

        // Count how many users are at the same location
        if (locationCount.containsKey(locationKey)) {
          locationCount[locationKey] = locationCount[locationKey]! + 1;
        } else {
          locationCount[locationKey] = 1;
        }

        // Offset markers slightly if more than one user is at the same location
        double offset = 0.0001 * (locationCount[locationKey]! - 1);

        LatLng adjustedPosition = LatLng(
          location.latitude + offset,
          location.longitude + offset,
        );

        // Customize marker color based on user type
        Color markerColor = Colors.yellow; // Default for others
        if (doc.id == currentUser.uid) {
          markerColor = Colors.blue; // Blue for the current user
        } else if (userData.containsKey('friends') && userData['friends'].contains(currentUser.uid)) {
          markerColor = Colors.green; // Green for friends
        }

        markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: adjustedPosition,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                markerColor == Colors.blue
                    ? BitmapDescriptor.hueBlue
                    : markerColor == Colors.green
                        ? BitmapDescriptor.hueGreen
                        : BitmapDescriptor.hueYellow),
            infoWindow: InfoWindow(
              title: userData['fullName'] ?? 'Unknown',
              snippet: userData['username'],
            ),
          ),
        );
      } else {
      }
    }

    setState(() {
      _markers = markers;
    });
  });
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

  String _generatePickupLocationId(LatLng location) {
    // R latitude and longitude to 3 decimal places (~111 meters precision)
    String lat = location.latitude.toStringAsFixed(3);
    String lng = location.longitude.toStringAsFixed(3);
    return '$lat,$lng';
  }

  Future<String> _createRideRequest(DateTime timeOfRide) async {
    User? user = _auth.currentUser;
    if (user == null) return '';

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
          'pickupLocations': FieldValue.arrayUnion([_pickupController.text]), // Update pickup locations array
          'dropoffLocations': FieldValue.arrayUnion([_dropoffController.text]),
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
        'pickupLocations': [_pickupController.text], // Store pickup locations as an array
        'dropoffLocations': [_dropoffController.text], // Store dropoff locations as an array
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

  // Retrieve the pickup locations and ensure they are LatLng objects
  List<LatLng> pickupLocationsList = [];
  for (var location in rideRequest['pickupLocations']) {
    pickupLocationsList.add(await _getLatLngFromAddress(location));
  }

  if (pickupLocationsList.isEmpty) return false;

  LatLng currentPickupLocation = await _getLatLngFromAddress(_pickupController.text);
  bool pickupProximityMatched = pickupLocationsList.any((location) =>
      _isWithinProximity(location, currentPickupLocation));

  if (!pickupProximityMatched) {
    return false;
  }

  // Retrieve the dropoff locations and ensure they are LatLng objects
  List<LatLng> dropoffLocationsList = [];
  for (var location in rideRequest['dropoffLocations']) {
    dropoffLocationsList.add(await _getLatLngFromAddress(location));
  }

  if (dropoffLocationsList.isEmpty) return false;

  LatLng currentDropoffLocation = await _getLatLngFromAddress(_dropoffController.text);

  bool isRouteValid = await _isValidRoute(currentPickupLocation, currentDropoffLocation, dropoffLocationsList);

  if (!isRouteValid) {
    return false;
  }

  // Retrieve the current user data
  DocumentSnapshot currentUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
  if (!currentUserDoc.exists) return false;

  Map<String, dynamic> currentUserData = currentUserDoc.data() as Map<String, dynamic>;

  List<String> participants = List<String>.from(rideRequest['participants']);
  int currentGroupSize = participants.length;

  for (String participantId in participants) {
    if (participantId == currentUser.uid) continue;

    DocumentSnapshot participantDoc = await _firestore.collection('users').doc(participantId).get();
    if (!participantDoc.exists) return false;

    Map<String, dynamic> participantData = participantDoc.data() as Map<String, dynamic>;

    if (!_doesUserMatchPreferences(currentUserData, participantData, currentGroupSize) ||
        !_doesUserDataMatchPreferences(participantData, currentUserData, currentGroupSize)) {
      return false;
    }
  }

  return true;
}

bool _doesUserMatchPreferences(Map<String, dynamic> currentUserData, Map<String, dynamic> targetData, int currentGroupSize) {
  Map<String, dynamic> userPrefs = currentUserData['preferences'];

  int userMinAge = userPrefs['ageRange']['min'];
  int userMaxAge = userPrefs['ageRange']['max'];
  int targetAge = targetData['age'];

  if (targetAge < userMinAge || targetAge > userMaxAge) {
    return false;
  }

  int userMinCapacity = userPrefs['minCarCapacity'];
  int userMaxCapacity = userPrefs['maxCarCapacity'];

  if (currentGroupSize + 1 < userMinCapacity || currentGroupSize + 1 > userMaxCapacity) {
    return false;
  }

  String? userDomain = currentUserData['domain'];
  String? targetDomain = targetData['domain'];

  if (userPrefs['schoolToggle'] == true && userDomain != targetDomain) {
    return false;
  }

  String? userGender = currentUserData['sexAssignedAtBirth'];
  String? targetGender = targetData['sexAssignedAtBirth'];

  if (userPrefs['sameGenderToggle'] == true && userGender != targetGender) {
    return false;
  }

  return true;
}

bool _doesUserDataMatchPreferences(Map<String, dynamic> participantData, Map<String, dynamic> currentUserData, int currentGroupSize) {
  Map<String, dynamic> participantPrefs = participantData['preferences'];

  int userAge = currentUserData['age'];
  int minAge = participantPrefs['ageRange']['min'];
  int maxAge = participantPrefs['ageRange']['max'];

  if (userAge < minAge || userAge > maxAge) {
    return false;
  }

  int participantMinCapacity = participantPrefs['minCarCapacity'];
  int participantMaxCapacity = participantPrefs['maxCarCapacity'];

  if (currentGroupSize + 1 < participantMinCapacity || currentGroupSize + 1 > participantMaxCapacity) {
    return false;
  }

  String? participantDomain = participantData['domain'];
  String? userDomain = currentUserData['domain'];

  if (participantPrefs['schoolToggle'] == true && participantDomain != userDomain) {
    return false;
  }

  String? participantGender = participantData['sexAssignedAtBirth'];
  String? userGender = currentUserData['sexAssignedAtBirth'];

  if (participantPrefs['sameGenderToggle'] == true && participantGender != userGender) {
    return false;
  }
  return true;
}

  Future<LatLng> _getLatLngFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      } else {
        throw Exception('No locations found for the given address.');
      }
    } catch (e) {
      throw Exception('Failed to get location from address: $e');
    }
  }

  bool _isWithinProximity(LatLng location1, LatLng location2) {
    const double maxDistance = 500; // 500 meters (we can change later)
    double distance = _calculateDistance(location1, location2);
    return distance <= maxDistance;
  }

  double _calculateDistance(LatLng location1, LatLng location2) {
    const double earthRadius = 6371000; // meters
    double lat1 = location1.latitude;
    double lon1 = location1.longitude;
    double lat2 = location2.latitude;
    double lon2 = location2.longitude;

    double dLat = (lat2 - lat1) * (pi / 180.0);
    double dLon = (lon2 - lon1) * (pi / 180.0);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) *
        sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
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

  void _navigateToLocationSearch(bool isPickup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSearchScreen(
          isPickup: isPickup,
          currentPosition: _currentPosition,
          onSelectAddress: (address) {
            if (isPickup) {
              _pickupController.text = address;
            } else {
              _dropoffController.text = address;
            }
          },
        ),
      ),
    );
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
      _firestore.collection('users').doc(currentUser.uid).collection('chats').snapshots().listen((snapshot) {
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
      title: const Text('Shuffl'),
      backgroundColor: Colors.yellow,
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
              color: Colors.yellow,
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
            title: const Text('Filtered Rides'),
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
            title: const Text('My Ride History'),
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
              ),
            ),
            style: const TextStyle(color: Colors.black),
            readOnly: true,
            onTap: () => _navigateToLocationSearch(false),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: _findRide,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50), // Make the button full width and tall
              backgroundColor: Colors.yellow,
            ),
            child: const Text('Find Ride Now', style: TextStyle(color: Colors.black)),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _showDateTimePicker,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow,
              ),
              child: const Text('Schedule Ahead', style: TextStyle(color: Colors.black)),
            ),
            Row(
              children: [
                const Text('Go Online', style: TextStyle(color: Colors.black)),
                Switch(
                  value: _goOnline,
                  onChanged: (value) {
                    _toggleGoOnline(value);
                  },
                  activeColor: Colors.green,
                ),
              ],
            ),
          ],
        ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: _currentPosition ?? _center,
                  zoom: 15.0,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                markers: _markers,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}