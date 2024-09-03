import 'package:flutter/material.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _showReportDialog(BuildContext context, String type) {
    final TextEditingController _usernameController = TextEditingController();
    final TextEditingController _descriptionController = TextEditingController();
    final TextEditingController _topicController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9, // Expanded width
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report $type',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (type == 'User') ...[
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username of Reported User',
                        labelStyle: const TextStyle(color: Colors.black),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                      style: const TextStyle(color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (type == 'Bug') ...[
                    TextField(
                      controller: _topicController,
                      decoration: InputDecoration(
                        labelText: 'Page with Bug',
                        labelStyle: const TextStyle(color: Colors.black),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                      style: const TextStyle(color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (type == 'Feedback') ...[
                    TextField(
                      controller: _topicController,
                      decoration: InputDecoration(
                        labelText: 'Topic',
                        labelStyle: const TextStyle(color: Colors.black),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black),
                        ),
                      ),
                      style: const TextStyle(color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _descriptionController,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true, // Align label with the top of the field
                      labelStyle: const TextStyle(color: Colors.black),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        User? currentUser = _auth.currentUser;
                        if (currentUser != null) {
                          Map<String, dynamic> reportData = {
                            'userId': currentUser.uid,
                            'timestamp': FieldValue.serverTimestamp(),
                            'description': _descriptionController.text,
                          };

                          if (type == 'User') {
                            reportData['reportedUsername'] = _usernameController.text;
                          } else if (type == 'Bug' || type == 'Feedback') {
                            reportData['topic'] = _topicController.text;
                          }

                          // Save report as a new document within the appropriate subcollection
                          try {
                            await _firestore
                                .collection('reports')
                                .doc(type.toLowerCase()) // Ensure a consistent path for subcollections
                                .collection('entries') // Use 'entries' as a subcollection to store individual reports
                                .add(reportData); // Creates a new document for each report

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$type reported successfully.')),
                            );

                            Navigator.pop(context);
                          } catch (e) {
                            print('Error reporting $type: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to submit report. Please try again.')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: const Text(
                        'Report',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report'),
        backgroundColor: kBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                _showReportDialog(context, 'User');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 15.0),
              ),
              child: const Text(
                'Report User',
                style: TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                _showReportDialog(context, 'Bug');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 15.0),
              ),
              child: const Text(
                'Report Bug',
                style: TextStyle(color: Colors.black),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                _showReportDialog(context, 'Feedback');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 15.0),
              ),
              child: const Text(
                'Report Feedback',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}