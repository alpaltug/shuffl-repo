import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/forgot_password_screen/forgot_password_screen.dart';
import 'package:my_flutter_app/widgets.dart';
import 'package:my_flutter_app/screens/signin/signin.dart';
import 'package:my_flutter_app/firestore_service.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  _ForgotPasswordState createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  String? _errorMessage;
  bool _isProcessing = false;

  void _sendResetLink() async {
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
    });

    String email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Email is required.';
        _isProcessing = false;
      });
      return;
    }

    bool emailExists = await _firestoreService.checkIfEmailExists(email);
    if (!emailExists) {
      setState(() {
        _errorMessage = 'No user found with this email.';
        _isProcessing = false;
      });
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'No user found with this email.';
            break;
          case 'invalid-email':
            _errorMessage = 'The email address is not valid.';
            break;
          default:
            _errorMessage = 'Failed to send reset link: ${e.message}';
            break;
        }
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LogolessAppBar(
        title: "Shuffl",
        automaticallyImplyLeading: true, // To show the back button
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(defaultPadding),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignIn()),
                            );
                          },
                        ),
                        const Text(
                          'Forgot Password',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Please fill out your email below in order to receive a reset password link.',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Email',
                      controller: _emailController,
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 20),
                    _isProcessing
                        ? const CircularProgressIndicator()
                        : GreenActionButton(
                            text: 'Send Reset Link',
                            onPressed: _sendResetLink,
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}