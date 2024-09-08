import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:my_flutter_app/widgets/green_action_button.dart';
import 'package:my_flutter_app/widgets/grey_text_field.dart';
import 'package:profanity_filter/profanity_filter.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/user_profile/user_profile.dart';

class UserPublicProfile extends StatefulWidget {
  const UserPublicProfile({super.key});

  @override
  _UserPublicProfileState createState() => _UserPublicProfileState();
}

class _UserPublicProfileState extends State<UserPublicProfile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ProfanityFilter _profanityFilter = ProfanityFilter();

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  // final TextEditingController _usernameController = TextEditingController();

  String? _displayName;
  String? _email;
  // String? _username;
  String? _description;
  String? _imageUrl;
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userProfile = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _displayName = userProfile['fullName'];
        _email = userProfile['email'];
        // _username = userProfile['username'];
        _description = userProfile['description'];
        _imageUrl = userProfile['imageUrl'];
        _descriptionController.text = _description ?? '';
        _nameController.text = _displayName ?? '';
        // _usernameController.text = _username ?? '';
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    setState(() {
      _imageFile = pickedFile;
    });
  }

  bool _containsProfanity(String input) {
    final words = input.split(RegExp(r'\s+'));
    for (var word in words) {
      if (_profanityFilter.hasProfanity(word)) {
        return true;
      }
    }
    return _profanityFilter.hasProfanity(input);
  }

  void _saveProfile() async {
    if (_nameController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full Name is required.')),
        );
      }
      return;
    }

    if (_descriptionController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Description is required.')),
        );
      }
      return;
    }

    if (_containsProfanity(_nameController.text) ||
        _containsProfanity(_descriptionController.text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please remove profanity from your profile details.')),
        );
      }
      return;
    }

    String? imageUrl;
    if (_imageFile != null) {
      String uid = _auth.currentUser!.uid;
      Reference storageRef = _storage.ref().child('profile_pics/$uid');
      UploadTask uploadTask = storageRef.putFile(File(_imageFile!.path));
      TaskSnapshot taskSnapshot = await uploadTask;
      imageUrl = await taskSnapshot.ref.getDownloadURL();
    }

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fullName': _nameController.text,
          'description': _descriptionController.text,
          'imageUrl': imageUrl != null && imageUrl.isNotEmpty ? imageUrl : _imageUrl,
        });
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const UserProfile(),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: kBackgroundColor,
        automaticallyImplyLeading: true,
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _imageFile != null
                          ? FileImage(File(_imageFile!.path))
                          : _imageUrl != null && _imageUrl!.isNotEmpty
                              ? NetworkImage(_imageUrl!)
                              : const AssetImage('assets/icons/ShuffleLogo.jpeg') as ImageProvider,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _showImageSourceActionSheet,
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
                      controller: _nameController,
                    ),
                    const SizedBox(height: 20),
                    // GreyTextField(
                    //   labelText: 'Username',
                    //   controller: _usernameController,
                    // ),
                    // const SizedBox(height: 20),
                    GreyTextField(
                      labelText: 'Short Description',
                      controller: _descriptionController,
                    ),
                    const SizedBox(height: 20),
                    if (_email != null)
                      Text(
                        _email!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    const SizedBox(height: 20),
                    GreenActionButton(
                      text: 'Save',
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