// // lib/widgets/invite_button_widget.dart

// import 'package:flutter/cupertino.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'dart:math';

// class InviteButtonWidget extends StatefulWidget {
//   const InviteButtonWidget({Key? key}) : super(key: key);

//   @override
//   _InviteButtonWidgetState createState() => _InviteButtonWidgetState();
// }

// class _InviteButtonWidgetState extends State<InviteButtonWidget> {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   String? _errorMessage;
//   bool _isLoading = false;

//   /// Generates a unique 6-character alphanumeric referral code
//   Future<String> _generateReferralCode() async {
//     const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
//     Random random = Random();
//     return String.fromCharCodes(
//       Iterable.generate(
//         6,
//         (_) => chars.codeUnitAt(random.nextInt(chars.length)),
//       ),
//     );
//   }

//   /// Ensures the referral code is unique by checking Firestore
//   Future<String> _generateUniqueReferralCode() async {
//     String code;
//     bool exists = true;

//     do {
//       code = await _generateReferralCode();
//       DocumentSnapshot doc = await _firestore.collection('referralCodes').doc(code).get();
//       exists = doc.exists;
//     } while (exists);

//     return code;
//   }

//   /// Retrieves the existing referral code or generates a new one
//   Future<String?> _getReferralCode() async {
//     try {
//       User? user = _auth.currentUser;
//       if (user == null) {
//         setState(() {
//           _errorMessage = 'User not authenticated.';
//         });
//         return null;
//       }

//       DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

//       if (userDoc.exists && userDoc['referralCode'] != null) {
//         return userDoc['referralCode'];
//       } else {
//         String referralCode = await _generateUniqueReferralCode();

//         // Save the referral code to the user's document using set with merge
//         await _firestore.collection('users').doc(user.uid).set({
//           'referralCode': referralCode,
//         }, SetOptions(merge: true));

//         // Create a new referral code document
//         await _firestore.collection('referralCodes').doc(referralCode).set({
//           'creatorParticipant': user.uid,
//           'users': [],
//         });

//         return referralCode;
//       }
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Failed to generate referral code: $e';
//       });
//       return null;
//     }
//   }

//   /// Sends the invitation message containing the referral code
//   Future<void> _sendInvitations() async {
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });

//     try {
//       String? referralCode = await _getReferralCode();

//       if (referralCode == null) {
//         // Show error message using SnackBar
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Failed to generate referral code.'),
//             backgroundColor: CupertinoColors.red,
//           ),
//         );
//         setState(() {
//           _isLoading = false;
//         });
//         return;
//       }

//       String message =
//           'Join me on Shuffl! Use my referral code $referralCode when signing up to get rewards. Download the app here: https://apps.apple.com/app/idYOUR_APP_ID';

//       Share.share(
//         message,
//         subject: 'Join me on Shuffl!',
//       );
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Failed to send invitations: $e';
//       });
//       // Show error message using SnackBar
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(_errorMessage!),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return CupertinoButton(
//       padding: EdgeInsets.zero,
//       child: _isLoading
//           ? const CupertinoActivityIndicator()
//           : const Icon(
//               CupertinoIcons.share,
//               color: CupertinoColors.black,
//             ),
//       onPressed: _isLoading ? null : _sendInvitations,
//     );
//   }
// }