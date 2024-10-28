import 'package:flutter/material.dart';

class RideDetailsPopup extends StatefulWidget {
  final List<Map<String, String>> participants;
  final Function(String pickupLocation, String dropoffLocation) onJoinRide;

  const RideDetailsPopup({
    required this.participants,
    required this.onJoinRide,
    Key? key,
  }) : super(key: key);

  @override
  _RideDetailsPopupState createState() => _RideDetailsPopupState();
}

class _RideDetailsPopupState extends State<RideDetailsPopup> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  String? _pickupLocation;
  String? _dropoffLocation;
  String? _pickupError;
  String? _dropoffError;

  void _openLocationSearchPage(bool isPickup) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSearchPage(
          isPickup: isPickup,
          onSelectAddress: (String address) {
            setState(() {
              if (isPickup) {
                _pickupLocation = address;
                _pickupController.text = address;
                _pickupError = null; // Clear error on selection
              } else {
                _dropoffLocation = address;
                _dropoffController.text = address;
                _dropoffError = null; // Clear error on selection
              }
            });
          },
        ),
      ),
    );
  }

  void _onFindRidePressed() {
    setState(() {
      _pickupError = _pickupLocation == null ? 'Please select a pickup location' : null;
      _dropoffError = _dropoffLocation == null ? 'Please select a dropoff location' : null;
    });

    if (_pickupLocation != null && _dropoffLocation != null) {
      widget.onJoinRide(_pickupLocation!, _dropoffLocation!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Join Ride",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          _buildLocationPicker("Pickup Location (Optional)", _pickupController, true),
          if (_pickupError != null)
            Text(
              _pickupError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          const SizedBox(height: 10),
          _buildLocationPicker("Dropoff Location (Optional)", _dropoffController, false),
          if (_dropoffError != null)
            Text(
              _dropoffError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          const SizedBox(height: 20),
          _buildParticipantsList(),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _onFindRidePressed,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              backgroundColor: Colors.green,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text("Join Ride", style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPicker(String label, TextEditingController controller, bool isPickup) {
    return GestureDetector(
      onTap: () => _openLocationSearchPage(isPickup),
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.location_on, color: Colors.black),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.grey),
            ),
          ),
          style: const TextStyle(color: Colors.black),
          readOnly: true,
        ),
      ),
    );
  }

  Widget _buildParticipantsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Participants",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        for (var participant in widget.participants)
          ListTile(
            leading: CircleAvatar(
              backgroundImage: participant['imageUrl'] != null && participant['imageUrl']!.isNotEmpty
                  ? NetworkImage(participant['imageUrl']!)
                  : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
              radius: 20,
            ),
            title: Text(participant['fullName'] ?? 'Unknown'),
            subtitle: Text(participant['username'] ?? 'Unknown'),
          ),
      ],
    );
  }
}

class LocationSearchPage extends StatelessWidget {
  final bool isPickup;
  final Function(String) onSelectAddress;

  const LocationSearchPage({
    Key? key,
    required this.isPickup,
    required this.onSelectAddress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isPickup ? "Select Pickup Location" : "Select Dropoff Location"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: isPickup ? "Enter pickup location" : "Enter dropoff location",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              style: const TextStyle(color: Colors.black),
              readOnly: false,
              onSubmitted: (String value) {
                onSelectAddress(value);
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
