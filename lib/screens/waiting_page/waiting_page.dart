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
  final TextEditingController _controller = TextEditingController();
  Set<Marker> _markers = {};
  List<DocumentSnapshot> _users = [];
  List<LatLng> _pickupLocations = [];
  Map<String, bool> _readyStatus = {};
  int _participantsCount = 0;
  LatLng loc = LatLng(0, 0);
  final LatLng _center = const LatLng(37.8715, -122.2730);
  List<LatLng> _dropoffLocations = [];
  DateTime? _rideTime;
  bool _locationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadRideDetails();
    _createGroupChat();
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

  void _loadRideDetails() {
    FirebaseFirestore.instance
        .collection('rides')
        .doc(widget.rideId)
        .snapshots()
        .listen((rideDoc) async {
      if (!mounted) return;
      if (rideDoc.exists) {
        // Check ride status and navigate when it becomes active
        if (rideDoc['isComplete'] == true) {
          _navigateToActiveRide(rideDoc);
          return; // Stop further processing once navigated
        }

        Set<LatLng> pickupLocations = {};
        Set<LatLng> dropoffLocations = {};

        // Populate pickup locations
        Map<String, String> pickupLocationsMap = Map<String, String>.from(rideDoc['pickupLocations']);
        for (var location in pickupLocationsMap.values) {
          pickupLocations.add(await _getLatLngFromAddress(location));
        }

        // Populate dropoff locations
        Map<String, String> dropoffLocationsMap = Map<String, String>.from(rideDoc['dropoffLocations']);
        for (var location in dropoffLocationsMap.values) {
          dropoffLocations.add(await _getLatLngFromAddress(location));
        }

        Map<String, bool> readyStatus = Map<String, bool>.from(rideDoc['readyStatus'] ?? {});
        int participantsCount = (rideDoc['participants'] as List).length;
        List<String> userIds = List<String>.from(rideDoc['participants']);
        List<DocumentSnapshot> userDocs = [];

        for (String uid in userIds) {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          userDocs.add(userDoc);
        }

        loc = pickupLocations.isNotEmpty ? pickupLocations.first : _center;

        if (mounted) {
          setState(() {
            _pickupLocations = pickupLocations.toList();
            _dropoffLocations = dropoffLocations.toList();
            _rideTime = (rideDoc['timeOfRide'] as Timestamp).toDate();
            _readyStatus = readyStatus;
            _participantsCount = participantsCount;
            _users = userDocs;
          });

          _loadMarkers();
          _checkMaxCapacity(rideDoc.reference);
        }
      } else {
        print('Ride document does not exist.');
      }
    });
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
      readyStatus[userId] = !currentStatus;

      transaction.update(rideDocRef, {'readyStatus': readyStatus});

      if (readyStatus.values.every((status) => status) && participants.length > 1) {
        transaction.update(rideDocRef, {'isComplete': true});
        shouldInitRide = true;
      }
    });

    if (shouldInitRide) {
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
        CameraUpdate.newLatLngZoom(_center, 15.0),
      );
    }
  }

  Future<void> _loadMarkers() async {
    Set<Marker> markers = {};

    for (LatLng location in _pickupLocations) {
      markers.add(Marker(
        markerId: MarkerId("user"),
        position: location,
      ));
    }

    if (mounted) {
      setState(() {
        _markers = markers;
      });
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
      bool isAlreadyInitialized = false;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot rideDoc = await transaction.get(rideDocRef);

        if (!rideDoc.exists) {
          print('Ride document does not exist.');
          return;
        }

        Map<String, dynamic> rideData = rideDoc.data() as Map<String, dynamic>;

        if (rideData['isComplete'] != true) {
          print('Ride is not complete yet.');
          return;
        }

        if (rideData['status'] == 'active') {
          isAlreadyInitialized = true;
          return;
        }

        List<LatLng> pickupLocations = [];
        Map<String, String> pickupLocationsMap = Map<String, String>.from(rideData['pickupLocations']);
        for (var location in pickupLocationsMap.values) {
          pickupLocations.add(await _getLatLngFromAddress(location));
        }

        LatLng midpoint = _calculateMidpoint(pickupLocations);

        rideData['pickupLocation'] = {
          'latitude': midpoint.latitude,
          'longitude': midpoint.longitude,
        };

        Map<String, String> dropoffLocationsMap = Map<String, String>.from(rideData['dropoffLocations']);
        rideData['dropoffLocations'] = dropoffLocationsMap;

        DocumentReference activeRideDocRef = FirebaseFirestore.instance
            .collection('active_rides')
            .doc(rideDocRef.id);

        rideData['startTime'] = FieldValue.serverTimestamp();
        rideData['status'] = 'active';

        transaction.set(activeRideDocRef, rideData);

        QuerySnapshot messagesSnapshot = await rideDocRef.collection('groupChat').get();
        for (var messageDoc in messagesSnapshot.docs) {
          transaction.set(
            activeRideDocRef.collection('groupChat').doc(messageDoc.id),
            messageDoc.data(),
          );
        }

        transaction.delete(rideDocRef);
      });

      if (!isAlreadyInitialized && mounted) {
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
              if (_pickupLocations.isNotEmpty || _dropoffLocations.isNotEmpty)
                Container(
                  height: 200,
                  child: GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _pickupLocations.isNotEmpty ? _pickupLocations.first : _center,
                      zoom: 14,
                    ),
                    markers: _markers,
                  ),
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
                            backgroundColor: isReady ? Colors.green : Colors.white,
                            foregroundColor: isReady ? Colors.white : Colors.black,
                            disabledBackgroundColor: isReady ? Colors.green : Colors.grey[300],
                            disabledForegroundColor: isReady ? Colors.white : Colors.grey[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18.0),
                            ),
                            side: BorderSide(color: isReady ? Colors.green : Colors.grey),
                          ),
                          child: Text(isReady ? 'Ready' : 'Unready'),
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
    _pickupLocations = await Future.wait(pickupAddresses.map((address) => _getLatLngFromAddress(address)).toList());
    _dropoffLocations = await Future.wait(dropoffAddresses.map((address) => _getLatLngFromAddress(address)).toList());

    _rideTime = (rideDoc['timeOfRide'] as Timestamp).toDate();

    if (mounted) {
      setState(() {});
    }
  }
} 