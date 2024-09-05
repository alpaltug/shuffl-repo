import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/widgets.dart';
import 'package:my_flutter_app/screens/friend_chat_screen/friend_chat_screen.dart';


class EditPreferencesPage extends StatefulWidget {
  final String uid;

  EditPreferencesPage({required this.uid});

  @override
  _EditPreferencesPageState createState() => _EditPreferencesPageState();
}

class _EditPreferencesPageState extends State<EditPreferencesPage> {
  double _currentMinAge = 18;
  double _currentMaxAge = 80;
  bool _sameGenderToggle = false;
  bool _sameSchoolToggle = false;
  int _minCarCapacity = 2;
  int _maxCarCapacity = 5;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    if (userDoc.exists) {
      setState(() {
        _currentMinAge = userDoc['preferences']['ageRange']['min'].toDouble();
        _currentMaxAge = userDoc['preferences']['ageRange']['max'].toDouble();
        _sameGenderToggle = userDoc['preferences']['sameGenderToggle'];
        _sameSchoolToggle = userDoc['preferences']['schoolToggle'];
        _minCarCapacity = userDoc['preferences']['minCarCapacity'];
        _maxCarCapacity = userDoc['preferences']['maxCarCapacity'];
      });
    }
  }

  Future<void> _updatePreferences() async {
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
      'preferences.ageRange.min': _currentMinAge.toInt(),
      'preferences.ageRange.max': _currentMaxAge.toInt(),
      'preferences.sameGenderToggle': _sameGenderToggle,
      'preferences.schoolToggle': _sameSchoolToggle,
      'preferences.minCarCapacity': _minCarCapacity,
      'preferences.maxCarCapacity': _maxCarCapacity,
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LogolessAppBar(
        title: 'Edit Preferences',
        automaticallyImplyLeading: true, // Remove the back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Age Range: ${_currentMinAge.toInt()} - ${_currentMaxAge.toInt()}',
              style: const TextStyle(color: Colors.black),
            ),
            RangeSlider(
              values: RangeValues(_currentMinAge, _currentMaxAge),
              min: 18,
              max: 80,
              divisions: 62,
              labels: RangeLabels(
                _currentMinAge.toInt().toString(),
                _currentMaxAge.toInt().toString(),
              ),
              activeColor: Colors.black, // Set active color to black
              inactiveColor: Colors.black.withOpacity(0.3), // Adjust inactive color
              onChanged: (RangeValues values) {
                setState(() {
                  _currentMinAge = values.start;
                  _currentMaxAge = values.end;
                });
              },
            ),
            Text(
              'Minimum Total People in Car: $_minCarCapacity',
              style: const TextStyle(color: Colors.black),
            ),
            Slider(
              value: _minCarCapacity.toDouble(),
              min: 2,
              max: 5,
              divisions: 3,
              label: _minCarCapacity.toString(),
              activeColor: Colors.black, // Set the slider color to black
              inactiveColor: Colors.black.withOpacity(0.3),
              onChanged: (double value) {
                setState(() {
                  _minCarCapacity = value.toInt();
                });
              },
            ),
            Text(
              'Maximum Total People in Car: $_maxCarCapacity',
              style: const TextStyle(color: Colors.black),
            ),
            Slider(
              value: _maxCarCapacity.toDouble(),
              min: 2,
              max: 5,
              divisions: 3,
              label: _maxCarCapacity.toString(),
              activeColor: Colors.black, // Set the slider color to black
              inactiveColor: Colors.black.withOpacity(0.3),
              onChanged: (double value) {
                setState(() {
                  _maxCarCapacity = value.toInt();
                });
              },
            ),
            SwitchListTile(
              title: const Text('Same Gender', style: TextStyle(color: Colors.black)),
              value: _sameGenderToggle,
              onChanged: (bool value) {
                setState(() {
                  _sameGenderToggle = value;
                });
              },
              activeColor: Colors.grey, // Keep this toggle different
              inactiveThumbColor: Colors.grey.withOpacity(0.6),
              activeTrackColor: Colors.black.withOpacity(0.3),
            ),
            SwitchListTile(
              title: const Text('Same School', style: TextStyle(color: Colors.black)),
              value: _sameSchoolToggle,
              onChanged: (bool value) {
                setState(() {
                  _sameSchoolToggle = value;
                });
              },
              activeColor: Colors.black, // Set the toggle color to black
              inactiveThumbColor: Colors.black.withOpacity(0.6),
              activeTrackColor: Colors.black.withOpacity(0.3),
            ),
            const Spacer(), // Push the button to the bottom
            Center(
              child: GreenActionButton(
                text: 'Save Preferences',
                onPressed: _updatePreferences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}