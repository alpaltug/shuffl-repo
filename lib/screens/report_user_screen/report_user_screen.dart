import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/constants.dart';

class ReportUserPage extends StatefulWidget {
  @override
  _ReportUserPageState createState() => _ReportUserPageState();
}

class _ReportUserPageState extends State<ReportUserPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Future<void> _submitReport() async {
    String username = _usernameController.text.trim();
    String description = _descriptionController.text.trim();

    if (username.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('reports/users').add({
      'username': username,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted successfully.')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report User'),
        backgroundColor: kBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Description (max 500 characters)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitReport,
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }
}