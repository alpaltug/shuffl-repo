import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';


 


class WaitingPage extends StatefulWidget {
  final String rideId;
  const WaitingPage({required this.rideId, Key? key}) : super(key: key);

  @override
  _WaitingPageState createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> {
  late GoogleMapController _mapController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Set<Marker> _markers = {};
  List<DocumentSnapshot> _users = [];
  List<String> _pickupLocations = [];

  @override
  void initState() {
    super.initState();
    _loadRideDetails();
  }

  Future<void> _loadRideDetails() async {
    DocumentSnapshot rideDoc = await FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .get();

    if (rideDoc.exists) {
      setState(() {
        _pickupLocations = List<String>.from(rideDoc['pickupLocations']);
        _loadMarkers();
      });

      List<String> userIds = List<String>.from(rideDoc['participants']);
      List<DocumentSnapshot> userDocs = [];
      for (String uid in userIds) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        userDocs.add(userDoc);
      }

      setState(() {
        _users = userDocs;
      });
    }
  }

  Future<void> _loadMarkers() async {
    Set<Marker> markers = {};

    for (String address in _pickupLocations) {
      LatLng location = await _getLatLngFromAddress(address);
      markers.add(Marker(
        markerId: MarkerId(address),
        position: location,
      ));
    }

    setState(() {
      _markers = markers;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Page'),
      ),
      body: Column(
        children: [
          if (_pickupLocations.isNotEmpty)
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

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                    ),
                    title: Text(fullName),
                    subtitle: Text('@$username'),
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
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
