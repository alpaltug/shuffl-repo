// TimeZoneDialog.dart

import 'package:flutter/material.dart';
// import 'package:flutter_native_timezone/flutter_native_timezone.dart'; // For fetching local timezone
import 'package:timezone/timezone.dart' as tz;

class TimeZoneDialog extends StatefulWidget {
  final String initialTimeZone;

  const TimeZoneDialog({Key? key, required this.initialTimeZone}) : super(key: key);

  @override
  _TimeZoneDialogState createState() => _TimeZoneDialogState();
}

class _TimeZoneDialogState extends State<TimeZoneDialog> {
  late String _selectedTimeZone;
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredTimeZones = [];

  @override
  void initState() {
    super.initState();
    _selectedTimeZone = widget.initialTimeZone;
    _filteredTimeZones = tz.timeZoneDatabase.locations.keys.toList()..sort();
  }

  void _filterTimeZones(String query) {
    setState(() {
      _filteredTimeZones = tz.timeZoneDatabase.locations.keys
          .where((tz) => tz.toLowerCase().contains(query.toLowerCase()))
          .toList()
        ..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Time Zone'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search Time Zones',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _filterTimeZones,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _filteredTimeZones.isEmpty
                ? const Center(child: Text('No time zones found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredTimeZones.length,
                    itemBuilder: (context, index) {
                      String timeZone = _filteredTimeZones[index];
                      return RadioListTile<String>(
                        title: Text(timeZone),
                        value: timeZone,
                        groupValue: _selectedTimeZone,
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _selectedTimeZone = value;
                            });
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, null); // Cancel selection
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _selectedTimeZone); // Confirm selection
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}