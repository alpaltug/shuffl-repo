import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/forgot_password/forgot_password.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/screens/login/login.dart';
import 'package:my_flutter_app/screens/create_profile/create_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/widgets/green_action_button.dart';
import 'package:my_flutter_app/widgets/grey_text_field.dart';
import 'package:my_flutter_app/widgets/logoless_appbar.dart';

class SignIn extends StatefulWidget {
  const SignIn({super.key});

  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  String? _errorMessage;

  Future<String?> _getEmailFromUsername(String username) async {
    try {
      QuerySnapshot snapshot = await _firestoreService.getUserByUsername(username);
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first['email'];
      }
    } catch (e) {
      print('Error fetching email from username: $e');
    }
    return null;
  }

  void _signIn() async {
    setState(() {
      _errorMessage = null;
    });

    String input = _emailController.text.trim();
    String email;

    if (input.contains('@')) {
      email = input;
    } else {
      email = await _getEmailFromUsername(input) ?? '';
    }

    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Invalid email or username';
      });
      return;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      User user = userCredential.user!;
      if (!user.email!.endsWith('.edu')) {
        setState(() {
          _errorMessage = 'Please use a school email address ending with .edu';
        });
        await _auth.signOut();
        return;
      }

      if (!user.emailVerified) {
        setState(() {
          _errorMessage = 'Please verify your email before logging in.';
        });
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = 'Email or username does not exist. Please check your input.';
            break;
          case 'invalid-email':
            _errorMessage = 'The email address is not valid.';
            break;
          case 'wrong-password':
            _errorMessage = 'Incorrect password. Please try again.';
            break;
          case 'user-disabled':
            _errorMessage = 'This user has been disabled. Please contact support.';
            break;
          default:
            _errorMessage = 'The email or password is incorrect. Try again.';
            break;
        }
      });
    }
  }

  void _signInWithGoogle() async {
    setState(() {
      _errorMessage = null;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth?.idToken,
        accessToken: googleAuth?.accessToken,
      );
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      User? user = userCredential.user;

      if (user != null && user.email != null && user.email!.endsWith('.edu')) {
        final userExists = await _firestoreService.checkIfUserExists(user.uid);
        if (userExists) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const HomePage(),
            ),
          );
        } else {
          await _firestoreService.addUser(user.uid, user.email!);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateProfile(),
            ),
          );
        }
      } else {
        await _deleteUser(user);
        await _auth.signOut();
        setState(() {
          _errorMessage = 'Please use a school email address ending with .edu';
        });
      }
    } on FirebaseAuthException {
      setState(() {
        _errorMessage = 'Failed to sign in with Google: Try Again.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign in with Google: Try Again.';
      });
    }
  }

  Future<void> _deleteUser(User? user) async {
    if (user != null) {
      try {
        await user.delete();
      } catch (e) {
        print('Failed to delete user: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LogolessAppBar(title: 'Shuffl', automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: defaultPadding),
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
                      labelText: 'Email or Username',
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
                        onPressed: _signInWithGoogle,
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