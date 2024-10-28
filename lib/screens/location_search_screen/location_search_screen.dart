import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:my_flutter_app/constants.dart';

class LocationSearchScreen extends StatefulWidget {
  final bool isPickup;
  final Function(String) onSelectAddress;
  final LatLng? currentPosition;

  const LocationSearchScreen({
    super.key,
    this.currentPosition,
    required this.isPickup,
    required this.onSelectAddress,
  });

  @override
  _LocationSearchScreenState createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _predictions = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _fetchPredictions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _predictions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=AIzaSyBvD12Z_T8Sw4fjgy25zvsF1zlXdV7bVfk';

    if (widget.currentPosition != null) {
      url +=
          '&location=${widget.currentPosition!.latitude},${widget.currentPosition!.longitude}&radius=50000';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          _predictions = jsonResponse['predictions'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load predictions';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load predictions';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPickup ? 'Pick-up Location' : 'Drop-off Location',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: kBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.isPickup ? 'Enter pick-up location' : 'Enter drop-off location',
                  prefixIcon: const Icon(Icons.location_on, color: kBackgroundColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                ),
                style: const TextStyle(color: Colors.black),
                onChanged: (query) => _fetchPredictions(query),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (_predictions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No locations found.',
                  style: TextStyle(color: Colors.black),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _predictions.length,
                  itemBuilder: (context, index) {
                    var prediction = _predictions[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          prediction['description'],
                          style: const TextStyle(color: Colors.black),
                        ),
                        leading: const Icon(Icons.place, color: kBackgroundColor),
                        onTap: () {
                          widget.onSelectAddress(prediction['description']);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
