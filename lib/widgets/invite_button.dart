// lib/widgets/invite_button_widget.dart

import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Needed for Colors
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';

class InviteButtonWidget extends StatefulWidget {
  const InviteButtonWidget({Key? key}) : super(key: key);

  @override
  _InviteButtonWidgetState createState() => _InviteButtonWidgetState();
}

class _InviteButtonWidgetState extends State<InviteButtonWidget> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _errorMessage;
  bool _isLoading = false;

  // Generates a unique referral code
  Future<String> _generateUniqueReferralCode() async {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    String code;
    bool exists = true;

    do {
      code = String.fromCharCodes(
        Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
      );
      DocumentSnapshot doc = await _firestore.collection('referralCodes').doc(code).get();
      exists = doc.exists;
    } while (exists);

    return code;
  }

  // Retrieves or creates a referral code for the user
  Future<String?> _getReferralCode() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not authenticated.';
        });
        return null;
      }

      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc['referralCode'] != null) {
        return userDoc['referralCode'];
      } else {
        String referralCode = await _generateUniqueReferralCode();

        // Save the referral code to the user's document
        await _firestore.collection('users').doc(user.uid).update({
          'referralCode': referralCode,
        });

        // Create a new referral code document
        await _firestore.collection('referralCodes').doc(referralCode).set({
          'creatorParticipant': user.uid,
          'users': [],
        });

        return referralCode;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate referral code: $e';
      });
      return null;
    }
  }

  // Sends the invitation message
  Future<void> _sendInvitations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? referralCode = await _getReferralCode();

      if (referralCode == null) {
        // Error message is already set in _getReferralCode
        setState(() {
          _isLoading = false;
        });
        return;
      }

      String message =
          'Shuffl lets you split rideshare costs! It is a carpool app that matches you with others that will be heading the same way as you at the same time based on your preferences. Use my referral code $referralCode when signing up to get rewards! Download the app here: https://apps.apple.com/us/app/shuffl-mobility/id6670162779';

      Share.share(
        message,
        subject: 'Join me on Shuffl!',
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send invitations: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Invite Icon Button
        Positioned(
          top: 0,
          right: 0,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            child: _isLoading
                ? const CupertinoActivityIndicator()
                : const Icon(
                    CupertinoIcons.share,
                    color: CupertinoColors.black,
                  ),
            onPressed: _sendInvitations,
          ),
        ),
        // Error Message Display
        if (_errorMessage != null)
          Positioned(
            top: 50,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}