import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class DirectionsWidget extends StatefulWidget {
  final LatLng destination;

  const DirectionsWidget({Key? key, required this.destination}) : super(key: key);

  @override
  _DirectionsWidgetState createState() => _DirectionsWidgetState();
}

class _DirectionsWidgetState extends State<DirectionsWidget> {
  late GoogleMapController _mapController;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
    });
    _mapController.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        14.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _currentPosition == null
        ? Center(child: CircularProgressIndicator())
        : GoogleMap(
            onMapCreated: (controller) => _mapController = controller,
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 14.0,
            ),
            markers: {
              Marker(
                markerId: MarkerId('currentLocation'),
                position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                infoWindow: InfoWindow(title: 'Your Location'),
              ),
              Marker(
                markerId: MarkerId('destination'),
                position: widget.destination,
                infoWindow: InfoWindow(title: 'Destination'),
              ),
            },
            polylines: {
              Polyline(
                polylineId: PolylineId('route'),
                visible: true,
                points: [
                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  widget.destination,
                ],
                color: Colors.blue,
                width: 5,
              ),
            },
          );
  }
}
