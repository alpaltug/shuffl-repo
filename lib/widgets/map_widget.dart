import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/widgets/create_custom_marker.dart'; 


class MapWidget extends StatefulWidget {
  final LatLng pickupLocation;
  final List<LatLng> dropoffLocations;
  final bool showCurrentLocation;
  final bool showDirections;
  final double initialZoom;
  final Set<Marker> participantMarkers;
  final List<String> participantIds;
  final String? userId;

  const MapWidget({
    Key? key,
    required this.pickupLocation,
    required this.dropoffLocations,
    this.showCurrentLocation = false,
    this.showDirections = false,
    this.initialZoom = 14.0,
    required this.participantMarkers,
    required this.participantIds,
    required this.userId,
  }) : super(key: key);

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  late GoogleMapController _controller;
  LatLng? _currentLocation;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _isMapReady = false;
  
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  // Load custom marker icons for pickup and dropoff
  // Future<void> _loadCustomMarkers() async {
  //   _pickupIcon = await BitmapDescriptor.fromAssetImage(
  //     const ImageConfiguration(size: Size(48, 48)),
  //     'assets/icons/pickup_icon.png',  // Add your custom pickup icon here
  //   );
    
  //   _dropoffIcon = await BitmapDescriptor.fromAssetImage(
  //     const ImageConfiguration(size: Size(48, 48)),
  //     'assets/icons/dropoff_icon.png', // Add your custom dropoff icon here
  //   );
  // }

  Future<void> _determinePosition() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _currentLocation = LatLng(position.latitude, position.longitude);

    setState(() {
      _currentLocation = _currentLocation;
    });

    _loadMarkers();

    if (widget.showDirections) {
      await _updateDirections();
    }
  }

  Future<void> _updateDirections() async {
    if (_currentLocation == null) return;

    // Draw route for the current user using their current location
    final currentUserRoute = await _getDirections(_currentLocation!, widget.pickupLocation);
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

    // Iterate over each participantId to fetch their lastPickupLocation from Firestore
    for (String participantId in widget.participantIds) {
      if (participantId == widget.userId) continue; // Skip the current user

      // Fetch the lastPickupLocation for each participant from Firestore
      DocumentSnapshot participantSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(participantId)
          .get();

      if (participantSnapshot.exists && participantSnapshot['lastPickupLocation'] != null) {
        GeoPoint lastPickupLocation = participantSnapshot['lastPickupLocation'];
        LatLng participantLocation = LatLng(lastPickupLocation.latitude, lastPickupLocation.longitude);

        // Fetch and draw the route for the participant from their lastPickupLocation to the ride's pickup location
        final participantRoute = await _getDirections(participantLocation, widget.pickupLocation);
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route_$participantId'),
              points: participantRoute,
              color: Colors.black, // Use blue for participant routes
              width: 5,
            ),
          );
        });
      }
    }
  }

  // Function to fetch directions from Google Directions API
  Future<List<LatLng>> _getDirections(LatLng start, LatLng end) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['routes'].isNotEmpty) {
        final route = jsonResponse['routes'][0];
        final overviewPolyline = route['overview_polyline']['points'];
        return _decodePolyline(overviewPolyline);
      } else {
        throw Exception('No routes found');
      }
    } else {
      throw Exception('Failed to fetch directions');
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
    Set<Marker> markers = {};

    // Use the custom pickup icon for pickup location
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickupLocation,
        //icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ),
    );

    // Use the custom dropoff icon for dropoff locations
    for (var dropoff in widget.dropoffLocations) {
      markers.add(
        Marker(
          markerId: MarkerId(dropoff.toString()),
          position: dropoff,
          //icon: _dropoffIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Dropoff Location'),
        ),
      );
    }

    // Marker for current location
    if (widget.showCurrentLocation && _currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: _currentLocation!,
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentLocation ?? widget.pickupLocation,
            zoom: widget.initialZoom,
          ),
          markers: _markers.union(widget.participantMarkers), // Combine markers and participantMarkers
          polylines: _polylines,
          myLocationEnabled: widget.showCurrentLocation,
          myLocationButtonEnabled: false, // Disable default Google button to use our custom button
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () {
              if (_currentLocation != null) {
                _controller.animateCamera(
                  CameraUpdate.newLatLngZoom(_currentLocation!, 15.0),
                );
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}