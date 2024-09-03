import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/constants.dart';

class ReportBugPage extends StatefulWidget {
  @override
  _ReportBugPageState createState() => _ReportBugPageState();
}

class _ReportBugPageState extends State<ReportBugPage> {
  final TextEditingController _pageController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Future<void> _submitReport() async {
    String page = _pageController.text.trim();
    String description = _descriptionController.text.trim();

    if (page.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('reports/bugs').add({
      'page': page,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bug report submitted successfully.')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Bug'),
        backgroundColor: kBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _pageController,
              decoration: const InputDecoration(labelText: 'Page with Bug'),
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