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
    print('Starting tests...');
    String sexTest = await _testGetUsersBySex();
    String ageRangeTest = await _testGetUsersByAgeRange();
    String schoolDomainTest = await _testGetUsersBySchoolDomain();

    setState(() {
      testResults = '$sexTest\n$ageRangeTest\n$schoolDomainTest';
    });
  }

  Future<String> _testGetUsersBySex() async {
    print('Testing getUsersBySex...');
    List<Map<String, dynamic>> maleUsers = await _firestoreService.getUsersBySex('Male');
    print('Male users: $maleUsers');
    List<Map<String, dynamic>> femaleUsers = await _firestoreService.getUsersBySex('Female');
    print('Female users: $femaleUsers');

    return 'Male Users: ${maleUsers.map((user) => user['username']).toList()}\nFemale Users: ${femaleUsers.map((user) => user['username']).toList()}';
  }

  Future<String> _testGetUsersByAgeRange() async {
    print('Testing getUsersByAgeRange...');
    List<Map<String, dynamic>> users18to25 = await _firestoreService.getUsersByAgeRange(18, 25);
    print('Users aged 18-25: $users18to25');
    List<Map<String, dynamic>> users26to35 = await _firestoreService.getUsersByAgeRange(26, 35);
    print('Users aged 26-35: $users26to35');

    return 'Users aged 18-25: ${users18to25.map((user) => user['username']).toList()}\nUsers aged 26-35: ${users26to35.map((user) => user['username']).toList()}';
  }

  Future<String> _testGetUsersBySchoolDomain() async {
    String userEmail = 'berkeley';  // Replace with email to test
    List<Map<String, dynamic>> sameSchoolUsers = await _firestoreService.getUsersBySchoolDomain(userEmail);
    print('Users with same school domain as $userEmail: $sameSchoolUsers');

    return 'Users with same school domain as $userEmail: ${sameSchoolUsers.map((user) => user['username']).join(', ')}';
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