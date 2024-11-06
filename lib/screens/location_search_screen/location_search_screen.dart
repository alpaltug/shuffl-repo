import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:my_flutter_app/constants.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

final String googleMapsApiKey = 'AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk';

class LocationSearchScreen extends StatefulWidget {
  final bool isPickup;
  final Function(String) onSelectAddress;
  final LatLng? currentPosition;

  const LocationSearchScreen({
    Key? key,
    this.currentPosition,
    required this.isPickup,
    required this.onSelectAddress,
  }) : super(key: key);

  @override
  _LocationSearchScreenState createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _predictions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        _fetchNearbyLocations();
      } else {
        _fetchPredictions(_searchController.text);
      }
    });
    _fetchNearbyLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPredictions(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$googleMapsApiKey&location=${widget.currentPosition?.latitude},${widget.currentPosition?.longitude}&radius=50000';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (data['status'] == 'OK') {
            _predictions = data['predictions'];
          } else {
            _errorMessage = 'Could not find locations. Please try again.';
            _predictions = [];
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch locations. Check your connection.';
          _predictions = [];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Try searching manually.';
        _predictions = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchNearbyLocations() async {
    if (widget.currentPosition == null) {
      setState(() {
        _errorMessage = 'Unable to get your location. Try searching manually.';
        _predictions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.currentPosition!.latitude,
        widget.currentPosition!.longitude,
      );

      if (placemarks.isNotEmpty) {
        setState(() {
          _predictions = [
            {
              'description': 'Current Location',
              'place_id': 'current_location',
            },
          ];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch nearby locations. Try searching.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLocationSelection(dynamic prediction) async {
    String address;
    if (prediction['place_id'] == 'current_location') {
      address = await _getAddressFromLatLng(widget.currentPosition!);
    } else {
      address = prediction['description'];
    }
    widget.onSelectAddress(address);
    Navigator.pop(context);
  }

  Future<String> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        return "${placemark.street}, ${placemark.locality}, ${placemark.country}";
      }
      return 'Unknown Location';
    } catch (e) {
      return 'Unknown Location';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kBackgroundColor, // Soft yellow background
      navigationBar: CupertinoNavigationBar(
        middle: Text(
          widget.isPickup ? 'Select Pickup Location' : 'Select Dropoff Location',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CupertinoTextField(
                controller: _searchController,
                placeholder: 'Search location',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(CupertinoIcons.search, color: Colors.black),
                ),
                suffix: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _fetchNearbyLocations();
                        },
                        child: const Icon(CupertinoIcons.clear_thick_circled,
                            color: Colors.black),
                      )
                    : null,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.black54,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : ListView.builder(
                        itemCount: _predictions.length,
                        itemBuilder: (context, index) {
                          final prediction = _predictions[index];
                          return Column(
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () =>
                                    _handleLocationSelection(prediction),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        prediction['place_id'] ==
                                                'current_location'
                                            ? CupertinoIcons.location_fill
                                            : CupertinoIcons.location,
                                        color: prediction['place_id'] ==
                                                'current_location'
                                            ? CupertinoColors.activeBlue
                                            : Colors.black54,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          prediction['description'],
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: CupertinoButton(
                      color: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: BorderRadius.circular(10),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
