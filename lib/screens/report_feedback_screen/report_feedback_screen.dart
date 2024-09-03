import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/constants.dart';

class ReportFeedbackPage extends StatefulWidget {
  @override
  _ReportFeedbackPageState createState() => _ReportFeedbackPageState();
}

class _ReportFeedbackPageState extends State<ReportFeedbackPage> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Future<void> _submitReport() async {
    String topic = _topicController.text.trim();
    String description = _descriptionController.text.trim();

    if (topic.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields.')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('reports/feedback').add({
      'topic': topic,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feedback submitted successfully.')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Feedback'),
        backgroundColor: kBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _topicController,
              decoration: const InputDecoration(labelText: 'Topic'),
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
              child: const Text('Submit Feedback'),
            ),
          ],
        ),
      ),
    );
  }
}