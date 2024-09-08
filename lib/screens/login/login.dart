import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:my_flutter_app/screens/create_profile/create_profile.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/screens/signin/signin.dart';
import 'package:my_flutter_app/screens/verification/verification_screen.dart'; 
import 'package:my_flutter_app/widgets/green_action_button.dart';
import 'package:my_flutter_app/widgets/grey_text_field.dart';
import 'package:my_flutter_app/widgets/logoless_appbar.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  // final TextEditingController _firstNameController = TextEditingController();
  // final TextEditingController _lastNameController = TextEditingController();
  // final TextEditingController _userNameController = TextEditingController();
  // final TextEditingController _phoneNumberController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  String? _errorMessage;

  void _register() async {
    setState(() {
      _errorMessage = null;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    // String firstName = _firstNameController.text.trim();
    // String lastName = _lastNameController.text.trim();
    // String userName = _userNameController.text.trim();
    // String phoneNumber = _phoneNumberController.text.trim();
    // String name = firstName + " " + lastName;

    if (!email.endsWith('.edu')) {
      setState(() {
        _errorMessage = 'Please use a school email address ending with .edu';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match. Please try again.';
      });
      return;
    }

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User user = userCredential.user!;
      await user.sendEmailVerification();

      await _firestoreService.addUser(user.uid, email);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const VerificationScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _errorMessage = 'The email address is already in use by another account.';
            break;
          case 'invalid-email':
            _errorMessage = 'The email address is not valid.';
            break;
          case 'weak-password':
            _errorMessage = 'The password is not strong enough.';
            break;
          default:
            _errorMessage = 'Failed to register: ${e.message}';
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
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign in with Google: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign in with Google: $e';
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
                      'Get Started',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Create an account or sign in if you already have an existing account. Please enter a school designated email to get verified!',
                      style: TextStyle(color: Colors.white),
                    ),
                    /*const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'First Name',
                      controller: _firstNameController,
                    ),*/
                    /*const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Last Name',
                      controller: _lastNameController,
                    ),*/
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Email',
                      controller: _emailController,
                    ),
                    /*const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Username',
                      controller: _userNameController,
                    ),*/
                    /*const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Phone Number',
                      controller: _phoneNumberController,
                    ),*/
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Password',
                      isPassword: true,
                      controller: _passwordController,
                    ),
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Confirm Password',
                      isPassword: true,
                      controller: _confirmPasswordController,
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 20),
                    GreenActionButton(
                      text: 'Create Account',
                      onPressed: _register,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Or sign up with',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: const Icon(Icons.g_translate_rounded, color: Colors.white),
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignIn(),
                            ),
                          );
                        },
                        child: const Text(
                          'Already have an account? Sign in here',
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

// APPLE SIGN IN BUTTON
  // const SizedBox(height: 20),
                    // SizedBox(
                    //   width: double.infinity,
                    //   child: OutlinedButton.icon(
                    //     onPressed: () {}, // BACKEND - Apple Sign In API
                    //     icon: const Icon(Icons.apple, color: Colors.white),
                    //     label: const Text(
                    //       'Continue with Apple',
                    //       style: TextStyle(color: Colors.white),
                    //     ),
                    //     style: OutlinedButton.styleFrom(
                    //       side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    //       padding: const EdgeInsets.symmetric(vertical: 16),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(10),
                    //       ),
                    //     ),
                    //   ),
                    // ),