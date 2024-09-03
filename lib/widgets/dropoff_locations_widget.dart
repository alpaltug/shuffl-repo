import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DropoffLocationsWidget extends StatelessWidget {
  final List<LatLng> dropoffLocations;

  const DropoffLocationsWidget({
    Key? key,
    required this.dropoffLocations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dropoff Locations:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ...dropoffLocations.map((location) {
            return Text(
              'Lat: ${location.latitude}, Lng: ${location.longitude}',
              style: const TextStyle(color: Colors.white),
            );
          }).toList(),
        ],
      ),
    );
  }
}
