import 'package:flutter/material.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/forgot_password/forgot_password.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/screens/login/login.dart';
import 'package:my_flutter_app/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _errorMessage;

  void _signIn() async {
    setState(() {
      _errorMessage = null; // Clear the previous error message
    });
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Navigate to the home page if the sign-in is successful
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
      );
    } catch (e) {
      if (e is FirebaseAuthException) {
        setState(() {
          if (e.code == 'user-not-found') {
            _errorMessage = 'Email does not exist. Please check your email.';
          } else if (e.code == 'wrong-password') {
            _errorMessage = 'Incorrect password. Please try again.';
          } else {
            _errorMessage = 'Failed to sign in: ${e.message}';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LogoAppBar(title: 'Shuffl'),
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
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Fill out the information below in order to access your account.',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Email',
                      controller: _emailController,
                    ),
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Password',
                      isPassword: true,
                      controller: _passwordController,
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 20),
                    GreenActionButton(
                      text: 'Sign In',
                      onPressed: _signIn,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Or sign in with',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {}, // BACKEND
                        icon: const Icon(Icons.g_translate, color: Colors.white),
                        label: const Text(
                          'Continue with Google',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {}, // BACKEND
                        icon: const Icon(Icons.apple, color: Colors.white),
                        label: const Text(
                          'Continue with Apple',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(context,
                            MaterialPageRoute(builder: (context) => const Login()));
                        },
                        child: const Text(
                          "Don't have an account? Create Account",
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(context,
                            MaterialPageRoute(builder: (context) => const ForgotPassword()));
                        },
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
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