import 'package:flutter/material.dart';

class ScheduleRideWidget extends StatefulWidget {
  final Function(DateTime timeOfRide, String pickupLocation, String dropoffLocation) onScheduleRide;
  final Function(bool isPickup, Function(String) onSelectAddress) onLocationSearch;

  const ScheduleRideWidget({
    Key? key,
    required this.onScheduleRide,
    required this.onLocationSearch,
  }) : super(key: key);

  @override
  _ScheduleRideWidgetState createState() => _ScheduleRideWidgetState();
}

class _ScheduleRideWidgetState extends State<ScheduleRideWidget> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _pickupLocation;
  String? _dropoffLocation;
  String? _dateTimeError;
  String? _pickupError;
  String? _dropoffError;

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();

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
            "Schedule a Ride",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          _buildDateTimePicker(),
          if (_dateTimeError != null)
            Text(
              _dateTimeError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          const SizedBox(height: 10),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton("CANCEL", Colors.grey[300], Colors.black, () {
                Navigator.pop(context);
              }),
              _buildActionButton("Schedule the Ride", Colors.yellow, Colors.black, _onScheduleRidePressed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return GestureDetector(
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );

        if (pickedDate != null) {
          TimeOfDay? pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );

          if (pickedTime != null) {
            setState(() {
              _selectedDate = pickedDate;
              _selectedTime = pickedTime;
              _dateTimeController.text = "${_selectedDate!.toLocal()}".split(' ')[0] +
                  ' at ' + _selectedTime!.format(context);
              _dateTimeError = null;
            });
          }
        }
      },
      child: AbsorbPointer(
        child: TextField(
          controller: _dateTimeController,
          decoration: InputDecoration(
            labelText: "Pick Date & Time",
            prefixIcon: const Icon(Icons.calendar_today, color: Colors.black),
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

  Widget _buildLocationPicker(String label, TextEditingController controller, bool isPickup) {
    return GestureDetector(
      onTap: () => widget.onLocationSearch(isPickup, (address) {
        setState(() {
          controller.text = address;
          if (isPickup) {
            _pickupLocation = address;
            _pickupError = null;
          } else {
            _dropoffLocation = address;
            _dropoffError = null;
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

  Widget _buildActionButton(String text, Color? backgroundColor, Color textColor, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        minimumSize: const Size(120, 50),
      ),
      child: Text(text),
    );
  }

  void _onScheduleRidePressed() {
    setState(() {
      _dateTimeError = _selectedDate == null || _selectedTime == null ? 'Please select a date and time' : null;
      _pickupError = _pickupLocation == null ? 'Please select a pickup location' : null;
      _dropoffError = _dropoffLocation == null ? 'Please select a dropoff location' : null;
    });

    if (_selectedDate != null &&
        _selectedTime != null &&
        _pickupLocation != null &&
        _dropoffLocation != null) {
      final selectedDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      widget.onScheduleRide(
        selectedDateTime,
        _pickupLocation!,
        _dropoffLocation!,
      );

      Navigator.pop(context);
    }
  }
}