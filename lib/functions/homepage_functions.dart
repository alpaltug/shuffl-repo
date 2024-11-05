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

import 'package:google_maps_flutter/google_maps_flutter.dart';


final googleMapsApiKey = 'AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk';

class HomePageFunctions {

    static const Color friendColor = Colors.green;
    static const Color tagColor = Colors.purple;
    static const Color normalUserColor = Colors.grey;

    // Toggle Visibility Option
    static Future<void> toggleVisibilityOption(
    String visibilityOption, // Accept visibility option instead of a boolean
    LatLng? currentPosition,
    FirebaseAuth auth,
    FirebaseFirestore firestore,
    Function(Function) updateState,
    Function(LatLng) updatePosition,
    Function(String) updateVisibilityOption, // Update visibility state
    Function fetchOnlineUsers,
    StreamSubscription<Position>? positionStreamSubscription,
    Set<Marker> markers,
    Function(Set<Marker>) updateMarkers,
    String rideId,
    String isActiveRide,
    ) async {
        User? user = auth.currentUser;
        if (user == null) return;

        updateState(() {
        // Update the visibility option state
        updateVisibilityOption(visibilityOption);
        });

        // Update the user's visibility option in Firestore
        await firestore.collection('users').doc(user.uid).update({
        'visibilityOption': visibilityOption,
        'currentPosition': currentPosition != null
            ? GeoPoint(currentPosition.latitude, currentPosition.longitude)
            : null,
        });

        if (visibilityOption != 'offline') {
            // Cancel the existing position stream subscription if it exists
            await determinePosition(auth, firestore, updatePosition, positionStreamSubscription, markers, updateState);
        } else {
        // If offline, cancel position updates and remove location from Firestore
        await firestore.collection('users').doc(user.uid).update({
            'currentPosition': null,
        });
        await positionStreamSubscription?.cancel();
        positionStreamSubscription = null;
        }

        // Fetch online users to update markers
        if (rideId == '0') {
            print('fetching online users');
            await fetchOnlineUsers(auth, firestore, updateMarkers, currentPosition, markers, visibilityOption);
        } else {
            print('fetching online participants');
            await fetchOnlineParticipants(auth, firestore, updateMarkers, currentPosition, markers, rideId, isActiveRide, visibilityOption);
        }
    }

    static bool _isFriend(FirebaseAuth auth, DocumentSnapshot currentUserData, DocumentSnapshot otherUserData) {
        try {
            User? user = auth.currentUser;
            if (user == null) return false;

            List<String> currentUserFriends = List<String>.from(currentUserData['friends'] ?? []);
            //print('Current user friends: $currentUserFriends');

            return currentUserFriends.contains(otherUserData.id);
        } catch (e) {
            print('Error checking if the user is a friend: $e');
            return false;
        }
    }

    static bool _isTag(FirebaseAuth auth, DocumentSnapshot currentUserData, DocumentSnapshot otherUserData) {
        try {
            User? user = auth.currentUser;
            if (user == null) return false;

            // Safely get and filter the tags lists, ensuring no null or empty strings are present
            List<String> currentUserTags = List<String>.from(currentUserData['tags'] ?? []).where((tag) => tag.isNotEmpty).toList();
            
            // Cast data to Map<String, dynamic> to check for keys safely
            Map<String, dynamic>? otherUserDataMap = otherUserData.data() as Map<String, dynamic>?;
            List<String> otherUserTags = otherUserDataMap != null && otherUserDataMap.containsKey('tags') 
                ? List<String>.from(otherUserDataMap['tags']).where((tag) => tag.isNotEmpty).toList() 
                : [];

            // print('Current user tags: $currentUserTags, Other user tags: $otherUserTags');

            if (currentUserTags.isEmpty || otherUserTags.isEmpty) return false;
            return currentUserTags.any((tag) => otherUserTags.contains(tag));
        } catch (e) {
            print('Error checking if the user is a tag: $e');
            return false;
        }
    }


    static Future<bool> _shouldDisplayUser(
    String otherUserId,
    FirebaseAuth auth,
    {required DocumentSnapshot currentUserData,
    required DocumentSnapshot otherUserData,
    required String currentUserVisibility,
    required String otherUserVisibility, // Change type to dynamic
    }) async {
        User? user = auth.currentUser;
        // print('1Checking if the user should be displayed, other user visibility: $otherUserVisibility');
        if (user == null) return false;
        if (otherUserId == user.uid) return false;

        // Ensure 'otherUserVisibility' is a string
        if (otherUserVisibility is! String) {
            otherUserVisibility = 'offline';
        }

        if (otherUserVisibility == 'offline') return false;
        if (otherUserVisibility == 'everyone') return true;

        // Fetch friends and tags for both users
        List<String> currentUserFriends = (currentUserData.data() as Map<String, dynamic>).containsKey('friends')
            ? List<String>.from(currentUserData['friends'])
            : [];

        List<String> otherUserFriends = (otherUserData.data() as Map<String, dynamic>).containsKey('friends')
            ? List<String>.from(otherUserData['friends'])
            : [];

        List<String> currentUserTags = (currentUserData.data() as Map<String, dynamic>).containsKey('tags')
            ? List<String>.from(currentUserData['tags'])
            : [];

        List<String> otherUserTags = (otherUserData.data() as Map<String, dynamic>).containsKey('tags')
            ? List<String>.from(otherUserData['tags'])
            : [];

        if (otherUserVisibility == 'friends' && _isFriend(auth, currentUserData, otherUserData)) {
            return true;
        }

        if (otherUserVisibility == 'tags' && _isTag(auth, currentUserData, otherUserData)) {
            return true;
        }

        if (otherUserVisibility == 'tags_and_friends' &&
            (otherUserFriends.contains(user.uid) ||
                currentUserTags.any((tag) => otherUserTags.contains(tag)))) {
            return true;
        }

        return false;
    }

    static Future<void> fetchGoOnlineStatus(
    FirebaseAuth auth,
    FirebaseFirestore firestore,
    Function(String) updateGoOnlineState
    ) async {
        User? user = auth.currentUser;
        if (user != null) {
            DocumentSnapshot userDoc = await firestore
                .collection('users')
                .doc(user.uid)
                .get();

            if (userDoc.exists) {
                // Get the 'goOnline' value from the user document, defaulting to 'offline' if not found
                String goOnlineValue = userDoc['goOnline'] ?? 'offline';
                
                // Call the callback to update the goOnline state
                updateGoOnlineState(goOnlineValue);
            } else {
                // If the document doesn't exist, set the goOnline state to 'offline'
                updateGoOnlineState('offline');
            }
        } else {
            // If no user is logged in, set the goOnline state to 'offline'
            updateGoOnlineState('offline');
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

    // Fetch Online Participants for a specific ride with a real-time listener
    static Future<void> fetchOnlineParticipants(
        FirebaseAuth auth,
        FirebaseFirestore firestore,
        Function(Set<Marker>) updateMarkers,
        LatLng? currentPosition,
        Set<Marker> markers,
        String rideId,  // New rideId parameter to fetch participants for the specific ride
        String isActiveRide,
        String visibilityOption,
    ) async {
        User? currentUser = auth.currentUser;
        Set<Marker> onlineMarkers = {};
        // if (currentUser == null || currentPosition == null || rideId.isEmpty) return;
        if (currentUser == null || rideId.isEmpty) return;

        DocumentSnapshot curUserData = await firestore.collection('users').doc(currentUser.uid).get();

        //print('Fetching online participants for ride: $rideId');

        // Query the active_rides collection to get participants for the specified ride
        String docTable = 'rides';
        if (isActiveRide == '2') {
            docTable = 'active_rides';
        } 
        print('DocTable: $docTable');
        firestore.collection(docTable).doc(rideId).snapshots().listen((DocumentSnapshot rideDoc) async {
            if (!rideDoc.exists) return;  // If no such ride, exit early

            Map<String, dynamic> rideData = rideDoc.data() as Map<String, dynamic>;
            List<dynamic> participants = rideData['participants'] ?? [];

            Set<Marker> waitingMarkers = {};
            Map<String, int> locationCount = {};
            final DateTime now = DateTime.now();

            // Iterate through the list of participants in the ride
            for (String participantId in participants) {
                DocumentSnapshot doc = await firestore.collection('users').doc(participantId).get();
                // Get the participant's document from the 'users' collection
                if (!doc.exists) continue;

                var userData = doc.data() as Map<String, dynamic>;

                // Ignore current user
                if (participantId == currentUser.uid) continue;

                // Retrieve goOnline as String
                dynamic otherUserVisibility = userData['goOnline'] ?? 'offline';
                if (otherUserVisibility is bool) {
                    otherUserVisibility = otherUserVisibility ? 'everyone' : 'offline';
                } else if (otherUserVisibility is! String) {
                    otherUserVisibility = 'offline';
                }

                // Determine if the current user should see this user based on visibility settings
                bool shouldDisplay = await _shouldDisplayUser(
                    participantId,
                    auth,
                    currentUserData: curUserData,
                    otherUserData: doc,
                    currentUserVisibility: visibilityOption,
                    otherUserVisibility: otherUserVisibility,
                );
                // print('Username is: $username | Should display: $shouldDisplay | Visibility: $otherUserVisibility');

                if (shouldDisplay) {

                    // Check if the user has a valid lastPickupLocation and is marked as 'ready' in readyStatus
                    if (userData['lastPickupLocation'] != null && rideData['readyStatus'][participantId] == false) {
                        GeoPoint location = userData['lastPickupLocation'];

                        LatLng otherUserPosition = LatLng(location.latitude, location.longitude);

                        // Add the marker (without proximity check as per your note)
                        // print('Adding marker for user: $participantId');
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
                        // print('Adding marker for user: $displayName');
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
            }

            // Update the markers in real-time using the callback
            updateMarkers(waitingMarkers);
        });
    }

    // Update User Location in Firestore
    static Future<void> updateUserLocationInFirestore(
    LatLng currentPosition,
    FirebaseAuth auth,
    FirebaseFirestore firestore,
    ) async {
        User? user = auth.currentUser;
        if (user != null) {
            try {
                await firestore.collection('users').doc(user.uid).update({
                    'lastPickupLocation': GeoPoint(currentPosition.latitude, currentPosition.longitude),
                    'lastPickupTime': FieldValue.serverTimestamp(),
                });
            } on FirebaseException catch (e) {
                if (e.code == 'not-found') {
                    print('User document not found. Cannot update location.');
                    // Optionally, create the document or handle as needed
                } else {
                    print('FirebaseException updating user location: $e');
                }
            } catch (e) {
                print('Unknown error updating user location: $e');
            }
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

static double _getMarkerHue(Color color) {
  if (color == friendColor) {
    return BitmapDescriptor.hueGreen;
  } else if (color == tagColor) {
    return 270.0; // Custom hue value for purple
  } else {
    return BitmapDescriptor.hueYellow;
  }
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

    // Add the 'fetchOnlineUsers' function back into 'HomePageFunctions':
    static Future<void> fetchOnlineUsers(
    FirebaseAuth auth,
    FirebaseFirestore firestore,
    Function(Set<Marker>) updateMarkers,
    LatLng? currentPosition,
    Set<Marker> markers,
    String visibilityOption,
    ) async {
        User? currentUser = auth.currentUser;
        if (currentUser == null) return;

        DocumentSnapshot curUserDoc = await firestore.collection('users').doc(currentUser.uid).get();
        Map<String, dynamic> curUserData = curUserDoc.data() as Map<String, dynamic>;

        QuerySnapshot userDocs = await firestore.collection('users').get();
        Map<String, int> locationCount = {};

        Set<Marker> newMarkers = {};

        for (var doc in userDocs.docs) {
            Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
            String userId = doc.id;

            // Retrieve goOnline as String
            dynamic otherUserVisibility = userData['goOnline'] ?? 'offline';
            if (otherUserVisibility is bool) {
                otherUserVisibility = otherUserVisibility ? 'everyone' : 'offline';
            } else if (otherUserVisibility is! String) {
                otherUserVisibility = 'offline';
            }

            // Determine if the current user should see this user based on visibility settings
            bool shouldDisplay = await _shouldDisplayUser(
                userId,
                auth,
                currentUserData: curUserDoc,
                otherUserData: doc,
                currentUserVisibility: visibilityOption,
                otherUserVisibility: otherUserVisibility,
            );
            // print('Should display: $shouldDisplay | Visibility: $otherUserVisibility');

            if (shouldDisplay) {
                // Check if the user has a valid lastPickupLocation and lastPickupTime
                if (userData['lastPickupLocation'] != null) {
                    // print('Processing user: $userId');
                    try {
                        GeoPoint location = userData['lastPickupLocation'];
                        Timestamp lastPickupTime = userData['lastPickupTime'];

                        // Check if the last pickup time is within the last 15 minutes
                        // DateTime pickupTime = lastPickupTime.toDate();
                        // if (DateTime.now().difference(pickupTime).inMinutes > 15) {
                        // continue; // Skip users with old pickup times
                        // }

                        LatLng otherUserPosition = LatLng(location.latitude, location.longitude);

                        String locationKey = '${location.latitude},${location.longitude}';

                        if (locationCount.containsKey(locationKey)) {
                            locationCount[locationKey] = locationCount[locationKey]! + 1;
                        } else {
                            locationCount[locationKey] = 1;
                        }

                        // Adjust the position slightly to avoid marker overlap
                        double offset = 0.001 * (locationCount[locationKey]! - 1);
                        LatLng adjustedPosition = LatLng(location.latitude + offset, location.longitude + offset);

                        String? displayName = userData['fullName'];
                        String? username = userData['username'];
                        String? profileImageUrl = userData['imageUrl'];

                        // Determine marker color based on user type
                        Color markerColor = normalUserColor;
                        // print('user color: $markerColor');
                        if (_isFriend(auth, curUserDoc, doc)) {
                            markerColor = friendColor;
                        } else if (_isTag(auth, curUserDoc, doc)) {
                            markerColor = tagColor;
                        } else {
                            markerColor = normalUserColor; // Default
                        }
                        // print('user color: $markerColor');

                        MarkerId markerId = MarkerId(doc.id);

                        // Check if the profileImageUrl is null or empty, and handle it accordingly
                        BitmapDescriptor markerIcon;
                        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
                            // Use the profile image if available
                            markerIcon = await createCustomMarkerWithImage(profileImageUrl, borderColor: markerColor);
                        } else {
                            // Fallback to the default asset if no profile picture is available
                            markerIcon = await createCustomMarkerFromAsset(borderColor: markerColor);
                        }


                        // Create marker
                        Marker marker = Marker(
                            markerId: markerId,
                            position: adjustedPosition,
                            infoWindow: InfoWindow(
                                title: (markerColor == normalUserColor) ? null : username, // Show username only for friends or tags
                            ),
                            icon: markerIcon,
                        );

                        newMarkers.add(marker);
                    } catch (e) {
                        print('Error processing user $userId: $e');
                        continue; // Skip to the next user if there's an error
                    }
                }
            }
        }
        updateMarkers(newMarkers);
    }
}