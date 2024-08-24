import 'package:flutter/material.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/edit_preferences/edit_preferences.dart';
import 'package:my_flutter_app/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:profanity_filter/profanity_filter.dart';

class CreateProfile extends StatefulWidget {
  const CreateProfile({super.key});

  @override
  _CreateProfileState createState() => _CreateProfileState();
}

class _CreateProfileState extends State<CreateProfile> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _sexAssignedAtBirth;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? _imageUrl;
  String? _errorMessage;
  final filter = ProfanityFilter();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile != null) {
      String uid = _auth.currentUser!.uid;
      Reference storageRef = FirebaseStorage.instance.ref().child('profile_pics/$uid');
      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot taskSnapshot = await uploadTask;
      _imageUrl = await taskSnapshot.ref.getDownloadURL();
    }
  }

  bool _isValidUsername(String username) {
    final RegExp usernameRegExp = RegExp(r'^[a-zA-Z0-9]+$');
    return username.length >= 6 && username.length <= 20 && usernameRegExp.hasMatch(username);
  }

  Future<void> _saveProfile() async {
    setState(() {
      _errorMessage = null;
    });

    if (_fullNameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Full Name is required.';
      });
      return;
    }

    if (_userNameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'A username is required.';
      });
      return;
    }

    if (_descriptionController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Description is required.';
      });
      return;
    }

    if (_ageController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Age is required.';
      });
      return;
    }

    int? age = int.tryParse(_ageController.text);
    if (age == null || age < 18 || age > 80) {
      setState(() {
        _errorMessage = 'Please enter a valid age between 18 and 80.';
      });
      return;
    }

    if (_sexAssignedAtBirth == null) {
      setState(() {
        _errorMessage = 'Sex assigned at birth is required.';
      });
      return;
    }

    if (filter.hasProfanity(_fullNameController.text) ||
        filter.hasProfanity(_userNameController.text) ||
        filter.hasProfanity(_descriptionController.text)) {
      setState(() {
        _errorMessage = 'Please remove profanity from your profile details.';
      });
      return;
    }

    if (!_isValidUsername(_userNameController.text)) {
      setState(() {
        _errorMessage = 'Username must be 6-20 characters long and can only contain alphabetic characters and numbers.';
      });
      return;
    }

    try {
      bool usernameExists = await _firestoreService.checkIfUsernameExists(_userNameController.text);
      if (usernameExists) {
        setState(() {
          _errorMessage = 'The username already exists. Please choose a different username.';
        });
        return;
      }

      await _uploadImage();

      User? user = _auth.currentUser;
      if (user != null) {
        await _firestoreService.updateUserProfile(
          user.uid,
          _fullNameController.text,
          _userNameController.text,
          _descriptionController.text,
          _imageUrl,
          _sexAssignedAtBirth!,
          age,
          goOnline: false,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EditPreferencesPage(uid: user.uid),
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
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => _pickImage(ImageSource.gallery),
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
                      labelText: 'Username',
                      controller: _userNameController,
                    ),
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Short Description',
                      controller: _descriptionController,
                    ),
                    const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Age',
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _sexAssignedAtBirth,
                      items: ['Male', 'Female']
                          .map((label) => DropdownMenuItem(
                                child: Text(label),
                                value: label,
                              ))
                          .toList(),
                      decoration: InputDecoration(
                        labelText: 'Select Sex Assigned at Birth',
                        labelStyle: const TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _sexAssignedAtBirth = value;
                        });
                      },
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white),
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