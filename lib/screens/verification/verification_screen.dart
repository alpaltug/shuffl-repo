import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/create_profile/create_profile.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;
  bool isEmailVerified = false;
  bool isChecking = false;

  Timer? emailCheckTimer;

  bool canResendEmail = true;
  int resendCooldown = 0; 
  Timer? resendTimer;

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    isChecking = true;
    checkEmailVerified();

    emailCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      checkEmailVerified();
    });
  }

  @override
  void dispose() {
    emailCheckTimer?.cancel();
    resendTimer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    await user?.reload();
    user = _auth.currentUser;
    if (user != null && user!.emailVerified) {
      setState(() {
        isEmailVerified = true;
      });
      emailCheckTimer?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CreateProfile()),
      );
    } else {
      setState(() {
        isChecking = false;
      });
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!canResendEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please wait $resendCooldown seconds before trying again.'),
        ),
      );
      return;
    }

    try {
      await user?.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email has been resent.'),
        ),
      );

      setState(() {
        canResendEmail = false;
        resendCooldown = 60; 
      });


      resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (resendCooldown > 0) {
            resendCooldown--;
          } else {
            canResendEmail = true;
            resendTimer?.cancel();
          }
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend verification email: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor, 
      appBar: AppBar(
        backgroundColor: kBackgroundColor, 
        title: const Text(
          'Email Verification',
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold, 
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'A verification email has been sent to your email address.',
                style: TextStyle(fontSize: 18, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Please check your email and verify your account before logging in.',
                style: TextStyle(fontSize: 16, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (isChecking)
                const CircularProgressIndicator(color: Colors.black),
              if (!isEmailVerified && !isChecking)
                Column(
                  children: [
                    ElevatedButton(
                      onPressed:
                          canResendEmail ? _resendVerificationEmail : null,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black, backgroundColor: Colors.white, 
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: canResendEmail
                          ? const Text('Resend Verification Email')
                          : Text(
                              'Resend in ${resendCooldown}s',
                              style: const TextStyle(color: Colors.black),
                            ),
                    ),
                    if (!canResendEmail)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Please wait $resendCooldown seconds before trying again.',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}