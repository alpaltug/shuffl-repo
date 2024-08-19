import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/widgets.dart';

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
      appBar: AppBar(
        title: Text('Edit Preferences'),
        backgroundColor: Colors.yellow,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Age Range: ${_currentMinAge.toInt()} - ${_currentMaxAge.toInt()}', style: TextStyle(color: Colors.black)),
            RangeSlider(
              values: RangeValues(_currentMinAge, _currentMaxAge),
              min: 18,
              max: 80,
              divisions: 62,
              labels: RangeLabels(
                _currentMinAge.toInt().toString(),
                _currentMaxAge.toInt().toString(),
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  _currentMinAge = values.start;
                  _currentMaxAge = values.end;
                });
              },
            ),
            SwitchListTile(
              title: Text('Same Gender'),
              value: _sameGenderToggle,
              onChanged: (bool value) {
                setState(() {
                  _sameGenderToggle = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Same School'),
              value: _sameSchoolToggle,
              onChanged: (bool value) {
                setState(() {
                  _sameSchoolToggle = value;
                });
              },
            ),
            Text('Minimum Total People in Car: $_minCarCapacity', style: TextStyle(color: Colors.black)),
            Slider(
              value: _minCarCapacity.toDouble(),
              min: 2,
              max: 5,
              divisions: 3,
              label: _minCarCapacity.toString(),
              onChanged: (double value) {
                setState(() {
                  _minCarCapacity = value.toInt();
                });
              },
            ),
            Text('Maximum Total People in Car: $_maxCarCapacity', style: TextStyle(color: Colors.black)),
            Slider(
              value: _maxCarCapacity.toDouble(),
              min: 2,
              max: 5,
              divisions: 3,
              label: _maxCarCapacity.toString(),
              onChanged: (double value) {
                setState(() {
                  _maxCarCapacity = value.toInt();
                });
              },
            ),
            SizedBox(height: 20),
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