import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class InviteService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> sendInvitations(BuildContext context) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Retrieve or generate referral code
      String? referralCode = await _getReferralCode(context, user);

      if (referralCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate referral code.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      String message =
          'Join me on Shuffl! Shuffl lets you split rideshare costs! It is a carpool app that matches you with others that will be heading the same way as you at the same time based on your preferences. Use my referral code $referralCode when signing up to get rewards. Download the app here: https://apps.apple.com/app/idYOUR_APP_ID';

      Share.share(
        message,
        subject: 'Join me on Shuffl!',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send invitations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<String?> _getReferralCode(BuildContext context, User user) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists && (userDoc.data() as Map<String, dynamic>).containsKey('referralCode')) {
        return userDoc['referralCode'];
      } else {
        String referralCode = await _generateUniqueReferralCode();

        // Save the referral code to the user's document
        await _firestore.collection('users').doc(user.uid).set({
          'referralCode': referralCode,
        }, SetOptions(merge: true));

        // Create a new referral code document
        await _firestore.collection('user_codes').doc(referralCode).set({
          'creatorParticipant': user.uid,
          'users': [],
        });

        return referralCode;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating referral code: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  static Future<String> _generateUniqueReferralCode() async {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    String code;
    bool exists = true;

    do {
      code = String.fromCharCodes(
        Iterable.generate(
          6,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ),
      );
      DocumentSnapshot doc = await _firestore.collection('user_codes').doc(code).get();
      exists = doc.exists;
    } while (exists);

    return code;
  }
}
