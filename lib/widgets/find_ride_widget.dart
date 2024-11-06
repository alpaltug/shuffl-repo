import 'package:flutter/material.dart';

class RideWidget extends StatefulWidget {
  final Function(String pickupLocation, String dropoffLocation) onSubmit;
  final Function(bool isPickup, Function(String) onSelectAddress) onLocationSearch;
  final List<Map<String, String>>? participants;
  final bool isJoinRide;

  const RideWidget({
    Key? key,
    required this.onSubmit,
    required this.onLocationSearch,
    this.participants,
    this.isJoinRide = false,
  }) : super(key: key);

  @override
  _RideWidgetState createState() => _RideWidgetState();
}

class _RideWidgetState extends State<RideWidget> {
  String? _pickupLocation;
  String? _dropoffLocation;
  String? _pickupError;
  String? _dropoffError;

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

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
          Text(
            widget.isJoinRide ? "Join Ride" : "Find a Ride",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          _buildLocationPicker("Pick-up Location", _pickupController, true),
          if (_pickupError != null)
            Text(
              _pickupError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          const SizedBox(height: 10),
          _buildLocationPicker("Drop-off Location", _dropoffController, false),
          if (_dropoffError != null)
            Text(
              _dropoffError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          const SizedBox(height: 20),
          if (widget.isJoinRide && widget.participants != null) _buildParticipantsList(),
          const SizedBox(height: 20),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildLocationPicker(String label, TextEditingController controller, bool isPickup) {
    return GestureDetector(
      onTap: () => widget.onLocationSearch(isPickup, (address) {
        setState(() {
          controller.text = address;
          if (isPickup) {
            _pickupLocation = address;
            _pickupError = null; // Clear error on valid input
          } else {
            _dropoffLocation = address;
            _dropoffError = null; // Clear error on valid input
          }
        });
      }),
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.location_on, color: Colors.black),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          style: const TextStyle(color: Colors.black),
          readOnly: true,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cancel button to close the widget
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300], // Gray color for cancel button
              foregroundColor: Colors.black, // Black text color
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text("CANCEL", style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 10), // Space between buttons
        Expanded(
          child: ElevatedButton(
            onPressed: _onSubmitPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow, // Yellow color for main action button
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(
              widget.isJoinRide ? "Join Ride" : "Find the Ride",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Participants",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 10),
        for (var participant in widget.participants!)
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

  void _onSubmitPressed() {
    // Validate inputs
    setState(() {
      _pickupError = _pickupLocation == null ? 'Please select a pickup location' : null;
      _dropoffError = _dropoffLocation == null ? 'Please select a dropoff location' : null;
    });

    // Proceed only if both locations are provided
    if (_pickupLocation != null && _dropoffLocation != null) {
      widget.onSubmit(_pickupLocation!, _dropoffLocation!);
      Navigator.pop(context);
    }
  }
}
