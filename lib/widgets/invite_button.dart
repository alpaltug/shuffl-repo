// lib/widgets/invite_button_widget.dart

import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math';

class InviteButtonWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
        // Handle unauthenticated user
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
      // Handle exceptions
      return null;
    }
  }

  // Sends the invitation message
  Future<void> sendInvitations(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      String? referralCode = await _getReferralCode();

      Navigator.of(context).pop(); // Close the loading indicator

      if (referralCode == null) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate referral code.')),
        );
        return;
      }

      String message =
          'Shuffl lets you split rideshare costs! It is a carpool app that matches you with others that will be heading the same way as you at the same time based on your preferences. Use my referral code $referralCode when signing up to get rewards! Download the app here: https://apps.apple.com/us/app/shuffl-mobility/id6670162779';

      Share.share(
        message,
        subject: 'Join me on Shuffl!',
      );
    } catch (e) {
      // Close the loading indicator if still open
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invitations: $e')),
      );
    }
  }
}
