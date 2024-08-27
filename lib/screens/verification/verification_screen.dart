import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/screens/create_profile/create_profile.dart';
import 'package:my_flutter_app/widgets.dart'; 

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

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    isChecking = true;
    checkEmailVerified();
  }

  Future<void> checkEmailVerified() async {
    await user?.reload();
    user = _auth.currentUser;
    print('Checking email verification status: ${user!.emailVerified}');
    if (user!.emailVerified) {
      setState(() {
        isEmailVerified = true;
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CreateProfile()),
      );
    } else {
      Future.delayed(const Duration(seconds: 1), checkEmailVerified);
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Email Verification'),
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
            if (!isEmailVerified && isChecking)
              const CircularProgressIndicator(),
            if (!isEmailVerified && !isChecking)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isChecking = true;
                  });
                  checkEmailVerified();
                },
                child: const Text('Check Verification Status'),
              ),
          ],
        ),
      ),
    ),
  );
}
}