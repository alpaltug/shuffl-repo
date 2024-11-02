import 'package:flutter/material.dart';
import 'package:my_flutter_app/constants.dart';
import 'package:my_flutter_app/screens/user_public_profile/user_public_profile.dart';
import 'package:my_flutter_app/screens/signin/signin.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/screens/user_friends/user_friends.dart';
import 'package:my_flutter_app/screens/search_users/search_users.dart';
import 'package:my_flutter_app/screens/blocked_users_screen/blocked_users_screen.dart';
import 'package:my_flutter_app/widgets/green_action_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? user;
  String? _displayName;
  String? _username;
  String? _imageUrl;
  double _averageRating = 0.0;
  int _numRides = 0;

  @override
  void initState() {
    super.initState();
    user = _auth.currentUser;
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userProfile =
          await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        _displayName = userProfile['fullName'];
        _username = userProfile['username'];
        _imageUrl = userProfile['imageUrl'];
        _averageRating = userProfile['rating'] ?? 0.0;
        _numRides = userProfile['numRides'] ?? 0;
      });
    }
  }

  Future<void> _deleteAccount(User user) async {
    try {
      // Ask for confirmation
      bool confirmed = await _showDeleteConfirmationDialog();
      if (!confirmed) {
        return; // User canceled deletion
      }

      // Determine the sign-in methods used by the user
      List<UserInfo> providerData = user.providerData;
      List<String> providers = providerData.map((info) => info.providerId).toList();

      // Reauthenticate the user based on their provider
      if (providers.contains('password')) {
        // Email/password user
        String? password = await _getPasswordFromUser();
        if (password == null) {
          // User canceled password input
          return;
        }
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      } else if (providers.contains('google.com')) {
        // Google sign-in user
        bool reauthenticated = await _reauthenticateWithGoogle();
        if (!reauthenticated) {
          return; // User canceled Google sign-in
        }
      } else if (providers.contains('apple.com')) {
        // Apple sign-in user
        bool reauthenticated = await _reauthenticateWithApple();
        if (!reauthenticated) {
          return; // User canceled Apple sign-in
        }
      } else {
        // Other providers not handled
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot delete account with this sign-in method.')),
        );
        return;
      }

      // Delete user document from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete the user from Firebase Auth
      await user.delete();

      // Navigate to the sign-in screen and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignIn()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error deleting user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'An error occurred while deleting your account. Please try again.',
          ),
        ),
      );
    }
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    String enteredUsername = '';
    bool confirmed = false;
    await showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(
            'Confirm Account Deletion',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            children: [
              SizedBox(height: 10),
              Text(
                'Deleting your account is a permanent action and cannot be undone. Please type your username to confirm you wish to proceed.',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 10),
              CupertinoTextField(
                onChanged: (value) {
                  enteredUsername = value;
                },
                placeholder: 'Enter your username',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            CupertinoDialogAction(
              child: Text('Delete'),
              isDestructiveAction: true,
              onPressed: () {
                if (enteredUsername == _username) {
                  confirmed = true;
                  Navigator.of(context).pop(); // Close the dialog
                } else {
                  Navigator.of(context).pop(); // Close the dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Username does not match. Account not deleted.'),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
    return confirmed;
  }

  Future<String?> _getPasswordFromUser() async {
    String? password;
    bool isCancelled = false;
    await showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(
            'Reauthenticate',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            children: [
              SizedBox(height: 10),
              Text(
                'Please enter your password to confirm account deletion:',
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 10),
              CupertinoTextField(
                obscureText: true,
                onChanged: (value) {
                  password = value;
                },
                placeholder: 'Password',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              child: Text('Cancel'),
              onPressed: () {
                isCancelled = true;
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
            CupertinoDialogAction(
              child: Text('Confirm'),
              onPressed: () {
                if (password == null || password!.isEmpty) {
                  // Show error message if password is empty
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password cannot be empty.')),
                  );
                } else {
                  Navigator.of(context).pop(); // Close the dialog
                }
              },
            ),
          ],
        );
      },
    );
    if (isCancelled) {
      return null;
    }
    return password;
  }

  Future<bool> _reauthenticateWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        return false;
      }
      final GoogleSignInAuthentication? googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );
      await user!.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      print('Error reauthenticating with Google: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reauthenticate with Google.')),
      );
      return false;
    }
  }

  Future<bool> _reauthenticateWithApple() async {
    try {
      final rawNonce = generateNonce();
      final hashedNonce = sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      await user!.reauthenticateWithCredential(oauthCredential);
      return true;
    } catch (e) {
      print('Error reauthenticating with Apple: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reauthenticate with Apple.')),
      );
      return false;
    }
  }

  String generateNonce([int length = 32]) {
    final charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
            length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: kBackgroundColor,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchUsers()),
              );
            },
          ),
        ],
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
                      backgroundImage: _imageUrl != null && _imageUrl!.isNotEmpty
                          ? NetworkImage(_imageUrl!)
                          : const AssetImage('assets/icons/ShuffleLogo.jpeg')
                              as ImageProvider,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _displayName ?? '[Display Name]',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _username ?? '[username]',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.yellow),
                        const SizedBox(width: 5),
                        Text(
                          '${_averageRating.toStringAsFixed(2)} | $_numRides rides',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildProfileOption(
                            icon: Icons.edit,
                            text: 'Edit Profile',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const UserPublicProfile(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildProfileOption(
                            icon: Icons.people,
                            text: 'Friends',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const UserFriends(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildProfileOption(
                            icon: Icons.block,
                            text: 'Blocked Users',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BlockedUsersScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GreenActionButton(
                      text: 'Log Out',
                      onPressed: () async {
                        await _auth.signOut();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const SignIn()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    GreenActionButton(
                      text: 'Delete Account',
                      onPressed: () async {
                        if (user != null) {
                          await _deleteAccount(user!);
                        }
                      },
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

  Widget _buildProfileOption({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(color: Colors.white),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }
}