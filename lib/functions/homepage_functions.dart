import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:my_flutter_app/widgets/create_custom_marker.dart';

final googleMapsApiKey = 'AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk';

class HomePageFunctions {
    // Toggle Go Online
    // Toggle Go Online
static Future<bool> toggleGoOnline(
  bool value,
  LatLng? currentPosition,
  FirebaseAuth auth,
  FirebaseFirestore firestore, 
  Function setState, 
  Function(LatLng) updatePosition,
  Function(bool) updateGoOnlineState,
  Function fetchOnlineUsers,
  StreamSubscription<Position>? positionStreamSubscription, 
  Set<Marker> markers
) async {
  User? user = auth.currentUser;
  if (user != null) {
    // Update user's online status in Firestore
    await firestore.collection('users').doc(user.uid).update({
      'goOnline': value,
    });

    // Update goOnline state in the UI
    updateGoOnlineState(value);

    if (value) {
      // Correctly pass the updatePosition callback here
      await determinePosition(auth, firestore, updatePosition, positionStreamSubscription, markers, setState);
    }

    // Fetch online users
    fetchOnlineUsers(auth, firestore, setState, markers, currentPosition);
  }

  return value;
}




    // Determine Position
    static Future<void> determinePosition(FirebaseAuth auth, FirebaseFirestore firestore, Function updatePosition, StreamSubscription<Position>? positionStreamSubscription, Set<Marker> markers, Function setState) async {
        positionStreamSubscription?.cancel(); // Cancel any previous subscription
        positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 100, // Update every 100 meters
            ),
        ).listen((Position position) async {
            LatLng newPosition = LatLng(position.latitude, position.longitude);
            await updateUserLocationInFirestore(newPosition, auth, firestore);

            // Update current position via callback
            updatePosition(newPosition);

            // Update location marker
            updateCurrentLocationMarker(newPosition, markers, setState);
        });
    }


    // Update Current Location Marker
    static void updateCurrentLocationMarker(LatLng position, Set<Marker> markers, Function setState) {
        setState(() {
            markers.removeWhere((marker) => marker.markerId.value == 'current_location');
            markers.add(
            Marker(
                markerId: const MarkerId("current_location"),
                position: position,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
            );
        });
    }

    // Fetch Online Users
    static Future<void> fetchOnlineUsers(FirebaseAuth auth, FirebaseFirestore firestore, Function setState, Set<Marker> markers, LatLng? currentPosition) async {
        User? currentUser = auth.currentUser;
        if (currentUser == null || currentPosition == null) return;

        firestore.collection('users').where('goOnline', isEqualTo: true).snapshots().listen((QuerySnapshot userSnapshot) async {
            Set<Marker> onlineMarkers = {};
            Map<String, int> locationCount = {};

            for (var doc in userSnapshot.docs) {
            var userData = doc.data() as Map<String, dynamic>;

            if (doc.id == currentUser.uid) continue;

            GeoPoint location = userData['lastPickupLocation'];
            LatLng otherUserPosition = LatLng(location.latitude, location.longitude);

            double distance = calculateDistance(currentPosition, otherUserPosition);

            if (distance >= 8046720) { // 5000 miles in meters
                String locationKey = '${location.latitude},${location.longitude}';
                if (locationCount.containsKey(locationKey)) {
                    locationCount[locationKey] = locationCount[locationKey]! + 1;
                } else {
                    locationCount[locationKey] = 1;
                }

                double offset = 0.0001 * (locationCount[locationKey]! - 1);
                LatLng adjustedPosition = LatLng(location.latitude + offset, location.longitude + offset);

                String? displayName = userData['fullName'];
                String? profileImageUrl = userData['imageUrl'];

                MarkerId markerId = MarkerId(doc.id);
                BitmapDescriptor markerIcon = await createCustomMarkerWithImage(profileImageUrl!);

                onlineMarkers.add(
                Marker(
                    markerId: markerId,
                    position: adjustedPosition,
                    icon: markerIcon,
                    infoWindow: InfoWindow(title: displayName),
                ),
                );
            }
            }

            setState(() {
            markers.addAll(onlineMarkers);
            });
        });
    }

    // Update User Location in Firestore
    static Future<void> updateUserLocationInFirestore(LatLng currentPosition, FirebaseAuth auth, FirebaseFirestore firestore) async {
        User? user = auth.currentUser;
        if (user != null) {
            await firestore.collection('users').doc(user.uid).update({
            'lastPickupLocation': GeoPoint(currentPosition.latitude, currentPosition.longitude),
            'lastPickupTime': FieldValue.serverTimestamp(),
            });
        }
    }

    // Get Address from LatLng
    static Future<String> getAddressFromLatLng(LatLng position) async {
        final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$googleMapsApiKey';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
            final jsonResponse = json.decode(response.body);
            return jsonResponse['results'][0]['formatted_address'] ?? 'Unknown location';
        } else {
            return 'Failed to get address';
        }
    }

    static Future<LatLng> getLatLngFromAddress(String address) async {
        final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$googleMapsApiKey');

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

        // Calculate Distance between two LatLng points
    static double calculateDistance(LatLng location1, LatLng location2) {
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
        return earthRadius * c;
    }
}
