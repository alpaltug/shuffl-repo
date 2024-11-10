import 'package:flutter/material.dart';
import 'package:my_flutter_app/screens/edit_preferences/edit_preferences.dart';
import 'package:my_flutter_app/screens/pdf_viewer/pdf_viewer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_flutter_app/firestore_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_flutter_app/widgets/green_action_button.dart';
import 'package:my_flutter_app/widgets/grey_text_field.dart';
import 'dart:io';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class CreateProfile extends StatefulWidget {
  const CreateProfile({Key? key}) : super(key: key);

  @override
  _CreateProfileState createState() => _CreateProfileState();
}

class _CreateProfileState extends State<CreateProfile> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  String? _sexAssignedAtBirth;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? _imageUrl;
  String? _errorMessage;
  final filter = ProfanityFilter();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProfile();
  }

  Future<void> _loadCurrentUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestoreService.getUserDocument(user.uid);
      if (userDoc.exists) {
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;
        if (userData != null) {
          setState(() {
            _fullNameController.text = userData['fullName'] ?? '';
            _userNameController.text = userData['username'] ?? '';
            _descriptionController.text = userData['description'] ?? '';
            _ageController.text = userData['age'] != null
                ? userData['age'].toString()
                : '';
            _sexAssignedAtBirth = userData['sexAssignedAtBirth'] ?? null;
            _imageUrl = userData['imageUrl'];
          });
        }
      }
    }
  }

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
      Reference storageRef =
          FirebaseStorage.instance.ref().child('profile_pics/$uid');
      UploadTask uploadTask = storageRef.putFile(_imageFile!);
      TaskSnapshot taskSnapshot = await uploadTask;
      _imageUrl = await taskSnapshot.ref.getDownloadURL();
    }
  }

  bool _isValidUsername(String username) {
    final RegExp usernameRegExp = RegExp(r'^[a-zA-Z0-9]+$');
    return username.length >= 6 &&
        username.length <= 20 &&
        usernameRegExp.hasMatch(username);
  }

  Future<String> _generateUniqueReferralCode() async {
    String code;
    bool exists = true;
    do {
      code = _generateRandomCode(6);
      exists = await _firestoreService.checkIfReferralCodeExists(code);
    } while (exists);
    return code;
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
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
        _errorMessage =
            'Username must be 6-20 characters long and can only contain alphabetic characters and numbers.';
      });
      return;
    }

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        String? existingUid =
            await _firestoreService.getUidByUsername(_userNameController.text);

        if (existingUid != null && existingUid != user.uid) {
          setState(() {
            _errorMessage =
                'The username already exists. Please choose a different username.';
          });
          return;
        }

        await _uploadImage();

        // Update user profile
        await _firestoreService.updateUserProfile(
          user.uid,
          _fullNameController.text,
          _userNameController.text,
          _descriptionController.text,
          _imageUrl,
          _sexAssignedAtBirth!,
          age,
          goOnline: "offline",
        );

        // Check if user has a referral code
        DocumentSnapshot userDoc =
            await _firestoreService.getUserDocument(user.uid);
        if (!userDoc.exists) {
          print('User document does not exist.');
          setState(() {
            _errorMessage = 'User document does not exist.';
          });
          return;
        } else {
          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;
          if (userData == null) {
            setState(() {
              _errorMessage = 'User data is null.';
            });
            return;
          }
          if (!userData.containsKey('referralCode')) {
            // Generate unique referral code
            String referralCode = await _generateUniqueReferralCode();
            // Save referral code to 'referral_codes' collection
            await _firestoreService.createReferralCode(referralCode, user.uid);
            // Update user document
            await _firestoreService.updateUserReferralCode(user.uid, referralCode);
          }
        }

        // If user entered a referral code
        if (_referralCodeController.text.isNotEmpty) {
          String enteredCode = _referralCodeController.text.trim();
          bool codeExists =
              await _firestoreService.checkIfReferralCodeExists(enteredCode);
          if (codeExists) {
            // Add current user's UID to 'users' array in that referral code document
            await _firestoreService.addUserToReferralCode(enteredCode, user.uid);
          } else {
            setState(() {
              _errorMessage = 'Invalid referral code.';
            });
            return;
          }
        }

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
      backgroundColor: Colors.yellow,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 50.0, 16.0, 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Create Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Adjust the content below to update your profile.',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    CircleAvatar(
                      radius: 45,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : _imageUrl != null
                              ? NetworkImage(_imageUrl!) as ImageProvider
                              : const AssetImage('assets/icons/ShuffleLogo.jpeg'),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 15),
                    GreyTextField(
                      labelText: 'Full Name',
                      controller: _fullNameController,
                    ),
                    const SizedBox(height: 15),
                    GreyTextField(
                      labelText: 'Username',
                      controller: _userNameController,
                    ),
                    const SizedBox(height: 15),
                    GreyTextField(
                      labelText: 'Short Description',
                      controller: _descriptionController,
                    ),
                    const SizedBox(height: 15),
                    GreyTextField(
                      labelText: 'Age',
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _sexAssignedAtBirth,
                      items: [
                        'Male',
                        'Female',
                        'Non-Binary',
                        'Prefer Not To Say'
                      ]
                          .map((label) => DropdownMenuItem(
                                value: label,
                                child: Text(label),
                              ))
                          .toList(),
                      decoration: InputDecoration(
                        labelText: 'Select Gender',
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
                    const SizedBox(height: 15),
                    GreyTextField(
                      labelText: 'Referral Code (Optional)',
                      controller: _referralCodeController,
                    ),
                    const SizedBox(height: 15),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 15),
                    GreenActionButton(
                      text: 'Save & Continue',
                      onPressed: _saveProfile,
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: 'By continuing you are agreeing to Shuffl\'s ',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        children: <TextSpan>[
                          TextSpan(
                            text: 'terms and conditions',
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PDFViewerPage(
                                      pdfAssetPath:
                                          'assets/Shuffl mobility Terms of Use.pdf',
                                      title: 'Terms and Conditions',
                                    ),
                                  ),
                                );
                              },
                          ),
                          const TextSpan(
                            text: ' and ',
                          ),
                          TextSpan(
                            text: 'privacy policy',
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PDFViewerPage(
                                      pdfAssetPath:
                                          'assets/Shuffl Privacy Policy Aug 2024.pdf',
                                      title: 'Privacy Policy',
                                    ),
                                  ),
                                );
                              },
                          ),
                        ],
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