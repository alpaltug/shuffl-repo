import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EnterReferralCodeScreen extends StatefulWidget {
  const EnterReferralCodeScreen({Key? key}) : super(key: key);

  @override
  _EnterReferralCodeScreenState createState() => _EnterReferralCodeScreenState();
}

class _EnterReferralCodeScreenState extends State<EnterReferralCodeScreen> {
  final TextEditingController _referralCodeController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submitReferralCode() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    String referralCode = _referralCodeController.text.trim();
    if (referralCode.isNotEmpty) {
      DocumentSnapshot doc = await _firestore
          .collection('referral_codes')
          .doc(referralCode)
          .get();

      if (doc.exists) {
        String orgName = doc['org_name'] ?? 'Unknown';
        User? user = _auth.currentUser;

        if (user != null) {
          try {
            // Get the 'members' array from the document, or an empty list if it doesn't exist
            List<dynamic> members = [];
            var data = doc.data() as Map<String, dynamic>;
            if (data.containsKey('members')) {
              members = data['members'];
            }

            // Check if the user is already a member
            if (members.contains(user.uid)) {
              // User is already a member
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('You are already a member of this organization/club.'),
                ),
              );
              setState(() {
                _isSubmitting = false;
              });
            } else {
              // Add the user to the 'members' array in the 'referral_codes' document
              await _firestore
                  .collection('referral_codes')
                  .doc(referralCode)
                  .set({
                'members': FieldValue.arrayUnion([user.uid]),
              }, SetOptions(merge: true));

              // Add the organization name to the user's 'tags'
              await _firestore.collection('users').doc(user.uid).set({
                'tags': FieldValue.arrayUnion([orgName]),
              }, SetOptions(merge: true));

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Referral code accepted! You have been tagged with $orgName.'),
                ),
              );
              Navigator.pop(context);
            }
          } catch (e) {
            setState(() {
              _errorMessage = 'An error occurred while updating your profile.';
              _isSubmitting = false;
            });
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid referral code.';
          _isSubmitting = false;
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Please enter a referral code.';
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _referralCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Enter Referral Code'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              CupertinoTextField(
                controller: _referralCodeController,
                placeholder: 'Referral Code',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _isSubmitting ? null : _submitReferralCode,
                child: _isSubmitting
                    ? const CupertinoActivityIndicator()
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
