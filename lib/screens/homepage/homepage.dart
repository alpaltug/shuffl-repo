import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_flutter_app/main.dart';
import 'package:my_flutter_app/screens/edit_preferences/edit_preferences.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:my_flutter_app/screens/search_users/search_users.dart';
import 'package:my_flutter_app/screens/notifications_screen/notifications_screen.dart';
import 'package:my_flutter_app/screens/location_search_screen/location_search_screen.dart';
import 'package:my_flutter_app/screens/chats_screen/chats_screen.dart';
import 'package:my_flutter_app/firestore_service.dart';
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
  int _uniqueMessageSenderCount = 0;
  final LatLng _center = const LatLng(37.8715, -122.2730); // our campus :)

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _determinePosition();
    _listenToUnreadMessageSenderCount();
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
      });
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
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error('Location permissions are permanently denied, we cannot request permissions.');
  }

  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  LatLng currentPosition = LatLng(position.latitude, position.longitude);
  String address = await _getAddressFromLatLng(currentPosition);

  setState(() {
    _currentPosition = currentPosition;
    _pickupController.text = address;
  });
}

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_currentPosition!, 15.0),
      );
    }
  }

  String _generatePickupLocationId(LatLng location) {
    // R latitude and longitude to 3 decimal places (~111 meters precision)
    String lat = location.latitude.toStringAsFixed(3);
    String lng = location.longitude.toStringAsFixed(3);
    return '$lat,$lng';
  }

  //New method to call when a ride request is created
  Future<void> _createRideRequest() async {
  User? user = _auth.currentUser;
  if (user == null) return;

  String pickupLocationId = _generatePickupLocationId(_currentPosition!);

  // Query ride requests with the same pickup location identifier
  QuerySnapshot existingRides = await _firestore
      .collection('rides')
      .where('pickupLocationId', isEqualTo: pickupLocationId)
      .get();

  bool matched = false;

  for (var doc in existingRides.docs) {
    // Placeholder for matching logic based on user preferences, etc.
    bool isMatch = _validateMatch(doc); // Implement this later

    if (isMatch) {
      // Add user to existing ride and update destinations
      await doc.reference.update({
        'participants': FieldValue.arrayUnion([user.uid]),
        'dropoffLocations': FieldValue.arrayUnion([_dropoffController.text]),
      });
      matched = true;
      break;
    }
  }

  if (!matched) {
    // Create a new ride request if no match was found
    await _firestore.collection('rides').add({
      'pickupLocationId': pickupLocationId,
      'pickupLocation': _pickupController.text,
      'dropoffLocations': [_dropoffController.text], // Store dropoff locations as an array
      'participants': [user.uid],
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}


  bool _validateMatch(DocumentSnapshot rideRequest) {
    // Implement the matching logic here in the future
    return true;
  }



//New method to call when the user clicks the "Find Ride" button
void _findRide() async {
  if (_pickupController.text.isNotEmpty && _dropoffController.text.isNotEmpty) {
    await _createRideRequest();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride request sent!')),
    );
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
                    _username ?? 'amk',
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
          // Add more drawer options here
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
        ElevatedButton(
          onPressed: _findRide,
          child: const Text('Find Ride'),
        ),
        Expanded(
          child: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
        ),
      ],
    ),
  );
  }
}