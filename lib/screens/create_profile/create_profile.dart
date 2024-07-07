import 'package:flutter/material.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/homepage/homepage.dart';
import 'package:my_flutter_app/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/firestore_service.dart';

class CreateProfile extends StatefulWidget {
  const CreateProfile({super.key});

  @override
  _CreateProfileState createState() => _CreateProfileState();
}

class _CreateProfileState extends State<CreateProfile> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  String? _errorMessage;

  void _saveProfile() async {
    setState(() {
      _errorMessage = null;
    });

    if (_fullNameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Full Name is required.';
      });
      return;
    }

    if (_descriptionController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Description is required.';
      });
      return;
    }

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestoreService.updateUserProfile(
          user.uid,
          _fullNameController.text,
          _phoneNumberController.text,
          _descriptionController.text,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomePage(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save profile: $e';
      });
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Create Profile',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Adjust the content below to update your profile.',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    const CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage('assets/icons/ShuffleLogo.jpeg'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Change Photo'),
                    ),
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Full Name',
                      controller: _fullNameController,
                    ),
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Phone Number (optional - lets implement this later)',
                      controller: _phoneNumberController,
                    ),
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Short Description',
                      controller: _descriptionController,
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 20),
                    GreenActionButton(
                      text: 'Save & Continue',
                      onPressed: _saveProfile,
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