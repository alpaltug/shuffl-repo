import 'package:flutter/material.dart';
import 'package:my_flutter_app/firestore_service.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final FirestoreService _firestoreService = FirestoreService();
  String testResults = '';

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    String sexTest = await _testGetUsersBySex();
    String ageRangeTest = await _testGetUsersByAgeRange();
    String schoolDomainTest = await _testGetUsersBySchoolDomain();

    setState(() {
      testResults = '$sexTest\n$ageRangeTest\n$schoolDomainTest';
    });
  }

  Future<String> _testGetUsersBySex() async {
    List<Map<String, dynamic>> maleUsers = await _firestoreService.getUsersBySex('male');
    List<Map<String, dynamic>> femaleUsers = await _firestoreService.getUsersBySex('female');

    return 'Male Users: ${maleUsers.map((user) => user['username']).toList()}\nFemale Users: ${femaleUsers.map((user) => user['username']).toList()}';
  }

  Future<String> _testGetUsersByAgeRange() async {
    List<Map<String, dynamic>> users18to25 = await _firestoreService.getUsersByAgeRange(18, 25);
    List<Map<String, dynamic>> users26to35 = await _firestoreService.getUsersByAgeRange(26, 35);

    return 'Users aged 18-25: ${users18to25.map((user) => user['username']).toList()}\nUsers aged 26-35: ${users26to35.map((user) => user['username']).toList()}';
  }

  Future<String> _testGetUsersBySchoolDomain() async {
    String userEmail = 'test@school.edu';  // Replace with an actual email for testing
    List<String> sameSchoolUsers = await _firestoreService.getUsersBySchoolDomain(userEmail);

    return 'Users with same school domain as $userEmail: $sameSchoolUsers';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(testResults, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}