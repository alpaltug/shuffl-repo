import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:my_flutter_app/screens/group_chats_screen/group_chats_screen.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:my_flutter_app/screens/view_user_profile/view_user_profile.dart';
import 'package:my_flutter_app/screens/active_rides_page/active_rides_page.dart';

class WaitingPage extends StatefulWidget {
  final String rideId;
  const WaitingPage({required this.rideId, Key? key}) : super(key: key);

  @override
  _WaitingPageState createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> {
  late GoogleMapController _mapController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _controller = TextEditingController();
  Set<Marker> _markers = {};
  List<DocumentSnapshot> _users = [];
  List<LatLng> _pickupLocations = [];
  Map<String, bool> _readyStatus = {};
  int _participantsCount = 0;
  LatLng loc = LatLng(0, 0);
  final LatLng _center = const LatLng(37.8715, -122.2730); // our campus :)

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
          _pickupLocations = [];
          Map<String, String> pickupLocationsMap = Map<String, String>.from(rideRequest['pickupLocations']);

          for (var location in pickupLocationsMap.values) {
            pickupLocationsList.add(await _getLatLngFromAddress(location));
          }
          _readyStatus = Map<String, bool>.from(rideDoc['readyStatus'] ?? {});
          _participantsCount = (rideDoc['participants'] as List).length;});

        List<String> userIds = List<String>.from(rideDoc['participants']);
        List<DocumentSnapshot> userDocs = [];
        for (String uid in userIds) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        userDocs.add(userDoc);
        }

        loc = _pickupLocations[0];

        setState(() {
        _users = userDocs;
        _loadMarkers();
        });

        _checkMaxCapacity(rideDoc.reference);
    } else {
        // Handle the case where the document does not exist
        print('Ride document does not exist.');
        // You can also show a message to the user or navigate back to a previous page
    }
}

Future<void> _toggleReadyStatus(String userId) async {
  if (userId != _auth.currentUser?.uid) return;

  DocumentReference rideDocRef =
      FirebaseFirestore.instance.collection('rides').doc(widget.rideId);

  DocumentSnapshot rideDoc = await rideDocRef.get();
  
  if (!rideDoc.exists) {
    print('Ride document does not exist.');
    return;
  }

  bool currentStatus = _readyStatus[userId] ?? false;
  setState(() {
    _readyStatus[userId] = !currentStatus;
  });

  await rideDocRef.update({
    'readyStatus.$userId': !currentStatus,
  });

  List<dynamic> participants = rideDoc['participants'];

  // Check if all participants are ready and there's more than one participant
  if (_readyStatus.values.every((status) => status) &&
      participants.length > 1) {
    await _initRide(rideDocRef);
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

  Future<void> _loadMarkers() async {
    Set<Marker> markers = {};

    for (LatLng location in _pickupLocations) {
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

  Future<void> _checkMaxCapacity(DocumentReference rideDocRef) async {
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

    await rideDocRef.update({
      'isComplete': isComplete,
    });
  }

  void _showMaxCapacityAlert(String username) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Max Capacity Reached",
              style: TextStyle(color: Colors.black)),
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
    DocumentSnapshot rideDoc = await rideDocRef.get();
    Map<String, dynamic> rideData = rideDoc.data() as Map<String, dynamic>;

    // Transfer chat messages from waiting room to active rides
    QuerySnapshot messagesSnapshot =
        await rideDocRef.collection('messages').get();
    List<Map<String, dynamic>> messages = messagesSnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    // Add to active_rides collection and get the new document ID
    DocumentReference activeRideDocRef = await FirebaseFirestore.instance
        .collection('active_rides')
        .add(rideData);

    // Transfer chat messages to active rides
    for (var message in messages) {
      await activeRideDocRef.collection('messages').add(message);
    }

    // Delete the ride document from the waiting room (including the chat)
    await rideDocRef.delete();

    // Navigate to active ride page using the new document ID
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => ActiveRidesPage(rideId: activeRideDocRef.id)),
    );
  }

  Future<void> _leaveGroup() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    DocumentReference rideDocRef =
        FirebaseFirestore.instance.collection('rides').doc(widget.rideId);

    // Remove the user from the participants array
    await rideDocRef.update({
      'participants': FieldValue.arrayRemove([user.uid]),
      'readyStatus.${user.uid}': FieldValue.delete(), // Remove the user's ready status
    });

    // Check the number of participants remaining
    DocumentSnapshot rideDoc = await rideDocRef.get();
    List<String> participants = List<String>.from(rideDoc['participants']);

    if (participants.isEmpty) {
      // If no participants are left, delete the ride document
      await rideDocRef.delete();
    } else {
      // Recalculate whether the ride is complete based on remaining participants
      int maxCapacity = 0;
      for (String participantId in participants) {
        DocumentSnapshot participantDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(participantId)
            .get();
        int participantMaxCapacity = participantDoc['preferences']
            ['maxCarCapacity'];
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

    // Navigate back to the homepage
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiting Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupChatScreen(rideId: widget.rideId),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pickupLocations.isNotEmpty)
            Container(
              height: 200,
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: CameraPosition(
                  target: loc ?? _center,
                  zoom: 14,
                ),
                markers: _markers,
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
                  var imageUrl = user.data().toString().contains('imageUrl')
                      ? user['imageUrl']
                      : null;
                  bool isReady = _readyStatus[user.id] ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 15),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                            ? NetworkImage(imageUrl)
                            : const AssetImage('assets/icons/ShuffleLogo.jpeg')
                                as ImageProvider,
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
                        onPressed: user.id == _auth.currentUser?.uid
                            ? () => _toggleReadyStatus(user.id)
                            : null, // Disable button for others
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isReady ? Colors.green : Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.0),
                          ),
                        ),
                        child: Text(isReady ? 'Unready' : 'Ready'),
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
                padding: const EdgeInsets.symmetric(
                    vertical: 12.0, horizontal: 20.0),
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
}