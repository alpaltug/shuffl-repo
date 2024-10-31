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
    Set<Marker> markers,
    Function(Set<Marker>) updateMarkers,
    String rideId,  // Named optional parameter with default value "0"
    String rideScreen,
    ) async {
        User? user = auth.currentUser;
        if (user != null) {
            // Update user's online status in Firestore
            await firestore.collection('users').doc(user.uid).update({
                'goOnline': value,
            });

            // Update goOnline state in the UI
            updateGoOnlineState(value);

            // Stop the existing listeners if toggled off
            if (!value) {
                positionStreamSubscription?.cancel(); // Cancel position listener

                // Remove the current user's marker from the markers set
                markers.removeWhere((marker) => marker.markerId.value == user.uid);
                updateMarkers(markers); // Update markers

                return value; // Stop further execution as the user is offline
            }

            // Stop the existing listeners if toggled off
            // if (!value) {
            //     positionStreamSubscription?.cancel(); // Cancel position listener
            //     updateMarkers({}); // Clear markers
            //     return value; // Stop further execution as the user is offline
            // }

            // If toggled on, determine position and fetch online users/participants
            if (value) {
                await determinePosition(auth, firestore, updatePosition, positionStreamSubscription, markers, setState);
            } else {
                //updateMarkers({}); // Clear markers
            }

            // Fetch online users or participants based on rideId
            if (rideId != "0" && rideScreen != "0") {
                print("Entering active ride for rideId: $rideId");
                fetchOnlineParticipants(auth, firestore, updateMarkers, currentPosition, markers, rideId, rideScreen);
            } else {
                //print("Entering normal online users");
                fetchOnlineUsers(auth, firestore, updateMarkers, currentPosition, markers);
            }
        }
        return value;
    }


    static Future<void> fetchGoOnlineStatus(
    FirebaseAuth auth,
    FirebaseFirestore firestore,
    Function(bool) updateGoOnlineState
    ) async {
        User? user = auth.currentUser;
        if (user != null) {
            DocumentSnapshot userDoc = await firestore
                .collection('users')
                .doc(user.uid)
                .get();

            if (userDoc.exists) {
                // Get the 'goOnline' value from the user document, defaulting to 'false' if not found
                bool goOnlineValue = userDoc['goOnline'] ?? false;
                
                // Call the callback to update the goOnline state
                updateGoOnlineState(goOnlineValue);
            } else {
                // If the document doesn't exist, set the goOnline state to false
                updateGoOnlineState(false);
            }
        } else {
            // If no user is logged in, set the goOnline state to false
            updateGoOnlineState(false);
        }
    }




    // Determine Position
    static Future<void> determinePosition(
    FirebaseAuth auth,
    FirebaseFirestore firestore,
    Function updatePosition,
    StreamSubscription<Position>? positionStreamSubscription,
    Set<Marker> markers,
    Function setState,
    ) async {
        // Cancel any previous subscription
        await positionStreamSubscription?.cancel();

        // Start listening to position updates with error handling
        positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update every 10 meters
        ),
        ).handleError((error) {
        // Handle location errors gracefully
        print('Error in position stream: $error');
        
        if (error is PermissionDeniedException) {
            print("Location permission denied. Please enable location access.");
            // Handle the specific error, such as showing a dialog to the user
        } else if (error is LocationServiceDisabledException) {
            print("Location services are disabled. Please enable them in settings.");
            // Handle the specific error, such as showing a dialog to the user
        } else {
            print("An unknown error occurred with geolocation.");
        }
        }).listen((Position position) async {
        try {
            // Process position updates
            LatLng newPosition = LatLng(position.latitude, position.longitude);
            
            // Update the user's location in Firestore
            await updateUserLocationInFirestore(newPosition, auth, firestore);

            // Fetch the profile image URL from Firestore
            // String? profileImageUrl = await _getProfileImageUrl(auth, firestore);

            // Optionally handle the marker update logic
            // BitmapDescriptor markerIcon;
            // if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
            //     markerIcon = await createCustomMarkerWithImage(profileImageUrl);
            // } else {
            //     markerIcon = await createCustomMarkerFromAsset();
            // }

            // Update current position via callback
            updatePosition(newPosition);

            // Update location marker with the user's profile image or default marker
            // updateCurrentLocationMarker(newPosition, markers, setState, markerIcon);
        } catch (e) {
            print('Error handling position update: $e');
            // Handle any additional errors during position update processing
        }
        });
    }

    // Helper function to fetch profileImageUrl from Firestore
    static Future<String?> _getProfileImageUrl(FirebaseAuth auth, FirebaseFirestore firestore) async {
        User? user = auth.currentUser;
        if (user != null) {
            DocumentSnapshot userDoc = await firestore.collection('users').doc(user.uid).get();
            if (userDoc.exists) {
                Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
                    return userData['imageUrl'] as String?;
                }
        }
        return null;
    }


    // Update Current Location Marker
    static void updateCurrentLocationMarker(LatLng position, Set<Marker> markers, Function setState, BitmapDescriptor markerIcon) {
        setState(() {
            markers.removeWhere((marker) => marker.markerId.value == 'current_location');
            markers.add(
                Marker(
                    markerId: const MarkerId("current_location"),
                    position: position,
                    icon: markerIcon,
                ),
            );
        });
    }

    // Fetch Online Users with a real-time listener
    static Future<void> fetchOnlineUsers(
    FirebaseAuth auth,
    FirebaseFirestore firestore,
    Function(Set<Marker>) updateMarkers,
    LatLng? currentPosition,
    Set<Marker> markers,
    ) async {
        User? currentUser = auth.currentUser;
        if (currentUser == null || currentPosition == null) return;

        // Listen to users who have goOnline set to true and whose lastPickupTime is within 15 minutes
        firestore.collection('users').where('goOnline', isEqualTo: true).snapshots().listen((QuerySnapshot userSnapshot) async {
            Set<Marker> onlineMarkers = {};
            Map<String, int> locationCount = {};
            final DateTime now = DateTime.now();

            for (var doc in userSnapshot.docs) {
                var userData = doc.data() as Map<String, dynamic>;
                //print('Username: ${userData['fullName']}');

                // Skip the current user
                //if (doc.id == currentUser.uid) continue;

                // Check if the user has a valid lastPickupLocation and lastPickupTime
                if (userData['lastPickupLocation'] != null) {
                    //print('User has a valid lastPickupLocation');
                    GeoPoint location = userData['lastPickupLocation'];
                    Timestamp lastPickupTime = userData['lastPickupTime'];

                    // Check if the last pickup time is within the last 15 minutes
                    // DateTime pickupTime = lastPickupTime.toDate();
                    // if (now.difference(pickupTime).inMinutes > 15) {
                    //     continue; // Skip users with old pickup times
                    // }

                    LatLng otherUserPosition = LatLng(location.latitude, location.longitude);

                    // Check proximity (5000 miles in meters)
                    double distance = HomePageFunctions.calculateDistance(currentPosition, otherUserPosition);
                    if (distance < 8046720) {
                        //print('User is within 5 miles, adding marker');
                        String locationKey = '${location.latitude},${location.longitude}';
                        if (locationCount.containsKey(locationKey)) {
                            locationCount[locationKey] = locationCount[locationKey]! + 1;
                        } else {
                            locationCount[locationKey] = 1;
                        }

                        // Adjust the position slightly to avoid marker overlap
                        double offset = 0.00002 * (locationCount[locationKey]! - 1);
                        LatLng adjustedPosition = LatLng(location.latitude + offset, location.longitude + offset);

                        String? displayName = userData['fullName'];
                        String? profileImageUrl = userData['imageUrl'];

                        MarkerId markerId = MarkerId(doc.id);

                        // Check if the profileImageUrl is null or empty, and handle it accordingly
                        BitmapDescriptor markerIcon;
                        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
                            // Use the profile image if available
                            markerIcon = await createCustomMarkerWithImage(profileImageUrl);
                        } else {
                            // Fallback to the default asset if no profile picture is available

                            markerIcon = await createCustomMarkerFromAsset();
                        }
                        //print('MarkerId: ${doc.id}');
                        markers.removeWhere((marker) => marker.markerId.value == doc.id);
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
            }

            // Update the markers in real-time using the callback
            updateMarkers(onlineMarkers);
        });
    }

    // Fetch Online Participants for a specific ride with a real-time listener
    static Future<void> fetchOnlineParticipants(
        FirebaseAuth auth,
        FirebaseFirestore firestore,
        Function(Set<Marker>) updateMarkers,
        LatLng? currentPosition,
        Set<Marker> markers,
        String rideId,  // New rideId parameter to fetch participants for the specific ride
        String isActiveRide,
    ) async {
        User? currentUser = auth.currentUser;
        // if (currentUser == null || currentPosition == null || rideId.isEmpty) return;
        if (currentUser == null || rideId.isEmpty) return;

        //print('Fetching online participants for ride: $rideId');

        // Query the active_rides collection to get participants for the specified ride
        String docTable = 'rides';
        if (isActiveRide == '2') {
            docTable = 'active_rides';
        }
        print('DocTable: $docTable');
        firestore.collection(docTable).doc(rideId).snapshots().listen((DocumentSnapshot rideDoc) async {
            if (!rideDoc.exists) return;  // If no such ride, exit early
            //print('Ride document exists for rideId: $rideId');

            Map<String, dynamic> rideData = rideDoc.data() as Map<String, dynamic>;
            List<dynamic> participants = rideData['participants'] ?? [];

            Set<Marker> onlineMarkers = {};
            Map<String, int> locationCount = {};
            final DateTime now = DateTime.now();

            // Iterate through the list of participants in the ride
            for (String participantId in participants) {
                //print('Checking participant with the uid: $participantId');
                // Skip the current user
                //if (participantId == currentUser.uid) continue;

                // Get the participant's document from the 'users' collection
                DocumentSnapshot userDoc = await firestore.collection('users').doc(participantId).get();
                if (!userDoc.exists) continue;

                var userData = userDoc.data() as Map<String, dynamic>;

                // Check if the user has a valid lastPickupLocation and lastPickupTime
                if (userData['lastPickupLocation'] != null && userData['goOnline'] == true) {
                    //print('User with the uid: $participantId is online');
                    GeoPoint location = userData['lastPickupLocation'];

                    LatLng otherUserPosition = LatLng(location.latitude, location.longitude);

                    if (true) {  // If within proximity, add the marker (skip this but have the structure)
                        print('adding marker for user: $participantId');
                        String locationKey = '${location.latitude},${location.longitude}';
                        if (locationCount.containsKey(locationKey)) {
                            locationCount[locationKey] = locationCount[locationKey]! + 1;
                        } else {
                            locationCount[locationKey] = 1;
                        }

                        // Adjust the position slightly to avoid marker overlap
                        double offset = 0.00001 * (locationCount[locationKey]! - 1);
                        LatLng adjustedPosition = LatLng(location.latitude + offset, location.longitude + offset);

                        String? displayName = userData['fullName'];
                        String? profileImageUrl = userData['imageUrl'];

                        MarkerId markerId = MarkerId(participantId);

                        // Check if the profileImageUrl is null or empty, and handle it accordingly
                        BitmapDescriptor markerIcon;
                        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
                            // Use the profile image if available
                            markerIcon = await createCustomMarkerWithImage(profileImageUrl);
                        } else {
                            // Fallback to the default asset if no profile picture is available
                            markerIcon = await createCustomMarkerFromAsset();
                        }
                        print('Adding marker for user: $displayName');
                        markers.removeWhere((marker) => marker.markerId.value == participantId);
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
            }

            // Update the markers in real-time using the callback
            updateMarkers(onlineMarkers);
        });
    }

    static Future<void> fetchWaitingParticipants(
    FirebaseAuth auth,
    FirebaseFirestore firestore,
    Function(Set<Marker>) updateMarkers,
    LatLng? currentPosition,
    Set<Marker> markers,
    String rideId,  // New rideId parameter to fetch participants for the specific ride
) async {
    User? currentUser = auth.currentUser;
    if (currentUser == null || rideId.isEmpty) return;

    // Query the rides collection to get participants for the specified ride
    firestore.collection('rides').doc(rideId).snapshots().listen((DocumentSnapshot rideDoc) async {
        if (!rideDoc.exists) return;  // If no such ride, exit early

        Map<String, dynamic> rideData = rideDoc.data() as Map<String, dynamic>;
        List<dynamic> participants = rideData['participants'] ?? [];

        Set<Marker> waitingMarkers = {};
        Map<String, int> locationCount = {};
        final DateTime now = DateTime.now();

        // Iterate through the list of participants in the ride
        for (String participantId in participants) {
            // Skip the current user
            //if (participantId == currentUser.uid) continue;

            // Get the participant's document from the 'users' collection
            DocumentSnapshot userDoc = await firestore.collection('users').doc(participantId).get();
            if (!userDoc.exists) continue;

            var userData = userDoc.data() as Map<String, dynamic>;

            // Check if the user has a valid lastPickupLocation and is marked as 'ready' in readyStatus
            if (userData['lastPickupLocation'] != null && rideData['readyStatus'][participantId] == false) {
                GeoPoint location = userData['lastPickupLocation'];

                LatLng otherUserPosition = LatLng(location.latitude, location.longitude);

                // Add the marker (without proximity check as per your note)
                print('Adding marker for user: $participantId');
                String locationKey = '${location.latitude},${location.longitude}';
                if (locationCount.containsKey(locationKey)) {
                    locationCount[locationKey] = locationCount[locationKey]! + 1;
                } else {
                    locationCount[locationKey] = 1;
                }

                // Adjust the position slightly to avoid marker overlap
                double offset = 0.00001 * (locationCount[locationKey]! - 1);
                LatLng adjustedPosition = LatLng(location.latitude + offset, location.longitude + offset);

                String? displayName = userData['fullName'];
                String? profileImageUrl = userData['imageUrl'];

                MarkerId markerId = MarkerId(participantId);

                // Check if the profileImageUrl is null or empty, and handle it accordingly
                BitmapDescriptor markerIcon;
                if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
                    // Use the profile image if available
                    markerIcon = await createCustomMarkerWithImage(profileImageUrl);
                } else {
                    // Fallback to the default asset if no profile picture is available
                    markerIcon = await createCustomMarkerFromAsset();
                }
                print('Adding marker for user: $displayName');
                markers.removeWhere((marker) => marker.markerId.value == participantId);
                waitingMarkers.add(
                    Marker(
                        markerId: markerId,
                        position: adjustedPosition,
                        icon: markerIcon,
                        infoWindow: InfoWindow(title: displayName),
                    ),
                );
            }
        }

        // Update the markers in real-time using the callback
        updateMarkers(waitingMarkers);
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

    static bool doesUserDataMatchPreferences(Map<String, dynamic> participantData, Map<String, dynamic> currentUserData, int currentGroupSize) {
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

  // Check "Same University" preference (includes domain and student status check)
  if (participantPrefs['sameUniversityToggle'] == true) {
      bool participantIsStudent = participantData['isStudent'] ?? false;
      bool userIsStudent = currentUserData['isStudent'] ?? false;
      if (!participantIsStudent || !userIsStudent || participantDomain != userDomain) {
          return false;
      }
  }

  // Check "Only Students" preference
  if (participantPrefs['onlyStudentsToggle'] == true) {
      bool userIsStudent = currentUserData['isStudent'] ?? false;
      if (!userIsStudent) {
          return false;
      }
  }

  String? participantGender = participantData['sexAssignedAtBirth'];
  String? userGender = currentUserData['sexAssignedAtBirth'];

  if (participantPrefs['sameGenderToggle'] == true && participantGender != userGender) {
      return false;
  }

  return true;
}

    static bool doesUserMatchPreferences(Map<String, dynamic> currentUserData, Map<String, dynamic> targetData, int currentGroupSize) {
  Map<String, dynamic> userPrefs = currentUserData['preferences'];

  int userMinAge = userPrefs['ageRange']['min'];
  int userMaxAge = userPrefs['ageRange']['max'];
  int targetAge = targetData['age'];

  // Check age range preference
  if (targetAge < userMinAge || targetAge > userMaxAge) {
    return false;
  }

  int userMinCapacity = userPrefs['minCarCapacity'];
  int userMaxCapacity = userPrefs['maxCarCapacity'];

  // Check car capacity preference
  if (currentGroupSize + 1 < userMinCapacity || currentGroupSize + 1 > userMaxCapacity) {
    return false;
  }

  String? userDomain = currentUserData['domain'];
  String? targetDomain = targetData['domain'];

  // Check "Same University" preference (includes student status and domain check)
  if (userPrefs['sameUniversityToggle'] == true) {
    bool userIsStudent = currentUserData['isStudent'] ?? false;
    bool targetIsStudent = targetData['isStudent'] ?? false;
    if (!userIsStudent || !targetIsStudent || userDomain != targetDomain) {
      return false;
    }
  }

  // Check "Only Students" preference
  if (userPrefs['onlyStudentsToggle'] == true) {
    bool targetIsStudent = targetData['isStudent'] ?? false;
    if (!targetIsStudent) {
      return false;
    }
  }

  String? userGender = currentUserData['sexAssignedAtBirth'];
  String? targetGender = targetData['sexAssignedAtBirth'];

  // Check same gender preference
  if (userPrefs['sameGenderToggle'] == true && userGender != targetGender) {
    return false;
  }

  return true; // All checks passed, preferences match
}

    static bool isWithinProximity(LatLng location1, LatLng location2) {
        const double maxDistance = 500; // 500 meters (we can change later)
        double distance = HomePageFunctions.calculateDistance(location1, location2);
        return distance <= maxDistance;
    }
}