import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geocoding/geocoding.dart';

class RatingPage extends StatefulWidget {
  final String rideId;
  final List<String> participants;

  const RatingPage({required this.rideId, required this.participants});

  @override
  _RatingPageState createState() => _RatingPageState();
}

class _RatingPageState extends State<RatingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, double> _ratings = {};
  DateTime? _rideEndTime;

  // Map-related variables
  GoogleMapController? _mapController;
  LatLng? _pickupLocation;
  LatLng? _dropoffLocation;
  String? _pickupAddress;
  String? _dropoffAddress;
  Set<Polyline> _polylines = {};
  String googleAPIKey = 'AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk'; // Replace with your actual API key

  // To keep track of which participants have already been rated
  Map<String, bool> _hasRated = {};

  // Store ratings data from ride document
  Map<String, dynamic>? _rideRatings;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadRideDetails();
    await _initializeRatings();
    if (_pickupAddress != null && _dropoffAddress != null) {
      await _getCoordinatesAndLoadMap();
    }
  }

  Future<void> _loadRideDetails() async {
    try {
      DocumentSnapshot rideDoc = await FirebaseFirestore.instance
          .collection('active_rides') // Changed from 'rides' to 'active_rides'
          .doc(widget.rideId)
          .get();

      if (rideDoc.exists) {
        Map<String, dynamic> rideData = rideDoc.data() as Map<String, dynamic>;

        // Assuming 'timestamp' is the ride end time
        Timestamp endTimeStamp = rideData['timestamp'];
        _rideEndTime = endTimeStamp.toDate();

        // Fetch pickup and dropoff addresses for the current user
        String currentUserId = _auth.currentUser!.uid;
        Map<String, dynamic>? pickupLocations = rideData['pickupLocations'] != null
            ? Map<String, dynamic>.from(rideData['pickupLocations'])
            : {};
        Map<String, dynamic>? dropoffLocations = rideData['dropoffLocations'] != null
            ? Map<String, dynamic>.from(rideData['dropoffLocations'])
            : {};

        setState(() {
          _pickupAddress = pickupLocations[currentUserId]?.toString() ?? 'Pickup address not available';
          _dropoffAddress = dropoffLocations[currentUserId]?.toString() ?? 'Dropoff address not available';
        });

        // Get existing ratings from ride document
        _rideRatings = rideData['ratings'] != null ? Map<String, dynamic>.from(rideData['ratings']) : {};
      } else {
        print('Ride document does not exist.');
      }
    } catch (e) {
      print('Error loading ride details: $e');
    }
  }

  Future<void> _getCoordinatesAndLoadMap() async {
    try {
      // Geocode pickup address
      List<Location> pickupLocations = await locationFromAddress(_pickupAddress!);
      if (pickupLocations.isNotEmpty) {
        setState(() {
          _pickupLocation = LatLng(pickupLocations.first.latitude, pickupLocations.first.longitude);
        });
      } else {
        print('No coordinates found for pickup address.');
      }

      // Geocode dropoff address
      List<Location> dropoffLocations = await locationFromAddress(_dropoffAddress!);
      if (dropoffLocations.isNotEmpty) {
        setState(() {
          _dropoffLocation = LatLng(dropoffLocations.first.latitude, dropoffLocations.first.longitude);
        });
      } else {
        print('No coordinates found for dropoff address.');
      }

      // Load the route polyline
      if (_pickupLocation != null && _dropoffLocation != null) {
        await _loadRoutePolyline();
      }

      setState(() {});
    } catch (e) {
      print('Error in geocoding addresses: $e');
    }
  }

  Future<void> _loadRoutePolyline() async {
    if (_pickupLocation == null || _dropoffLocation == null) return;

    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_pickupLocation!.latitude},${_pickupLocation!.longitude}&destination=${_dropoffLocation!.latitude},${_dropoffLocation!.longitude}&key=$googleAPIKey';

    try {
      var response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].length > 0) {
          String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          List<LatLng> polylinePoints = _decodePolyline(encodedPolyline);

          setState(() {
            _polylines.add(
              Polyline(
                polylineId: PolylineId('route'),
                points: polylinePoints,
                color: Colors.blue,
                width: 5,
              ),
            );
          });

          // Move camera to include the entire route
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(
              _getLatLngBounds(_pickupLocation!, _dropoffLocation!),
              50,
            ),
          );
        } else {
          print('No routes found in directions API response.');
        }
      } else {
        print('Error fetching directions: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading route polyline: $e');
    }
  }

  LatLngBounds _getLatLngBounds(LatLng pickup, LatLng dropoff) {
    double southWestLat = pickup.latitude < dropoff.latitude ? pickup.latitude : dropoff.latitude;
    double southWestLng = pickup.longitude < dropoff.longitude ? pickup.longitude : dropoff.longitude;
    double northEastLat = pickup.latitude > dropoff.latitude ? pickup.latitude : dropoff.latitude;
    double northEastLng = pickup.longitude > dropoff.longitude ? pickup.longitude : dropoff.longitude;

    return LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }

  Future<void> _initializeRatings() async {
    String currentUserId = _auth.currentUser!.uid;
    for (String participantId in widget.participants) {
      if (participantId != currentUserId) {
        // Check if the user has already rated this participant
        bool hasRated = false;
        if (_rideRatings != null && _rideRatings![participantId] != null) {
          List<dynamic> raters = _rideRatings![participantId];
          hasRated = raters.contains(currentUserId);
        }
        _ratings[participantId] = 5.0; // Default to 5 stars
        _hasRated[participantId] = hasRated;
      }
    }
    setState(() {});
  }

  void _updateRating(String participantId, double rating) {
    setState(() {
      _ratings[participantId] = rating;
    });
  }

  Future<void> _submitRatings() async {
    if (!_canRate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You can no longer submit ratings for this ride.')),
      );
      return;
    }

    String currentUserId = _auth.currentUser!.uid;

    // Update user ratings and ride document
    WriteBatch batch = FirebaseFirestore.instance.batch();
    DocumentReference rideRef = FirebaseFirestore.instance.collection('active_rides').doc(widget.rideId);

    Map<String, dynamic> updatedRatings = _rideRatings != null ? Map<String, dynamic>.from(_rideRatings!) : {};

    for (String participantId in _ratings.keys) {
      if (_hasRated[participantId] == true) {
        continue; // Skip if already rated
      }
      double rating = _ratings[participantId]!;

      // Update participant's rating in users collection
      await _firestoreService.updateUserRating(participantId, rating);

      // Update ride document's ratings field
      if (updatedRatings.containsKey(participantId)) {
        List<dynamic> raters = List<dynamic>.from(updatedRatings[participantId]);
        raters.add(currentUserId);
        updatedRatings[participantId] = raters;
      } else {
        updatedRatings[participantId] = [currentUserId];
      }
    }

    // Update the ride document with new ratings
    batch.update(rideRef, {'ratings': updatedRatings});

    try {
      await batch.commit();
    } catch (e) {
      print('Error submitting ratings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting ratings. Please try again.')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  bool _canRate() {
    if (_rideEndTime == null) return true;
    return DateTime.now().isBefore(_rideEndTime!.add(Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        title: const Text(
          'Ride History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map Widget
          _pickupLocation != null && _dropoffLocation != null
              ? Container(
                  height: 200,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        (_pickupLocation!.latitude + _dropoffLocation!.latitude) / 2,
                        (_pickupLocation!.longitude + _dropoffLocation!.longitude) / 2,
                      ),
                      zoom: 12,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    markers: {
                      Marker(
                        markerId: MarkerId('pickup'),
                        position: _pickupLocation!,
                        infoWindow: InfoWindow(title: 'Pickup'),
                      ),
                      Marker(
                        markerId: MarkerId('dropoff'),
                        position: _dropoffLocation!,
                        infoWindow: InfoWindow(title: 'Dropoff'),
                      ),
                    },
                    polylines: _polylines,
                  ),
                )
              : Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: Center(
                    child: Text(
                      'Map not available',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
          // Ride Details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _rideDetailBox(
                  icon: Icons.location_pin,
                  iconColor: Colors.green,
                  label: 'Pickup Location',
                  text: _pickupAddress ?? 'Pickup address not available',

                ),
                SizedBox(height: 8),
                _rideDetailBox(
                  icon: Icons.location_pin,
                  iconColor: Colors.red,
                  label: 'Dropoff Location',
                  text: _dropoffAddress ?? 'Dropoff address not available',
                ),
                SizedBox(height: 8),
                _rideEndTime != null
                    ? _rideDetailBox(
                        icon: Icons.calendar_today,
                        iconColor: Colors.blue,
                        label: 'Ride Ended On',
                        text: DateFormat.yMMMd().format(_rideEndTime!),
                      )
                    : Container(),
              ],
            ),
          ),
          Divider(color: Colors.white),
          // Participants List with Ratings
          Expanded(
            child: ListView.builder(
              itemCount: _ratings.length,
              itemBuilder: (context, index) {
                String participantId = _ratings.keys.elementAt(index);
                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(participantId).get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(title: Text('Loading...'));
                    }

                    if (snapshot.hasError) {
                      return const ListTile(title: Text('Error loading user data.'));
                    }

                    if (!snapshot.hasData || snapshot.data!.data() == null) {
                      return const ListTile(title: Text('User data not found.'));
                    }

                    Map<String, dynamic> userData = snapshot.data!.data() as Map<String, dynamic>;
                    String username = userData['username'] ?? 'Unknown User';
                    String? imageUrl = userData['imageUrl'] as String?;

                    return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 30,
                          backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                              ? NetworkImage(imageUrl)
                              : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                        ),
                        title: Text(username, style: const TextStyle(color: Colors.black)),
                        subtitle: _hasRated[participantId] == true
                            ? Text(
                                'You have already rated this user.',
                                style: TextStyle(color: Colors.black),
                              )
                            : StarRating(
                                rating: _ratings[participantId]!,
                                onRatingChanged: (rating) => _canRate() ? _updateRating(participantId, rating) : null,
                                enabled: _canRate(),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _canRate()
          ? FloatingActionButton(
              backgroundColor: Colors.black,
              onPressed: _submitRatings,
              child: const Icon(Icons.check, color: Colors.white),
            )
          : null,
    );
  }

  Widget _rideDetailBox({required IconData icon, required Color iconColor, required String label, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.black, fontSize: 14)),
                SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(color: Colors.black, fontSize: 14), 
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StarRating extends StatelessWidget {
  final double rating;
  final Function(double) onRatingChanged;
  final bool enabled;

  const StarRating({required this.rating, required this.onRatingChanged, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.black, 
          ),
          onPressed: enabled ? () => onRatingChanged(index + 1.0) : null,
        );
      }),
    );
  }
}