import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_flutter_app/constants.dart';

class ReferFriendScreen extends StatefulWidget {
  const ReferFriendScreen({Key? key}) : super(key: key);

  @override
  _ReferFriendScreenState createState() => _ReferFriendScreenState();
}

class _ReferFriendScreenState extends State<ReferFriendScreen> {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _referralCode;
  int _referralCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      if (userData == null || !userData.containsKey('referralCode')) {
        await _generateReferralCode();
      } else {
        setState(() {
          _referralCode = userData['referralCode'];
          _referralCount = userData['referralCount'] ?? 0;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load referral data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateReferralCode() async {
    try {
      final result = await _functions.httpsCallable('generateReferralCode').call();
      setState(() {
        _referralCode = result.data['referralCode'];
        _referralCount = 0;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate referral code: ${e.toString()}';
      });
    }
  }

  void _shareReferralCode() {
    if (_referralCode != null) {
      Share.share('Join me on Shuffl! Use my referral code: $_referralCode');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Refer a Friend',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: kBackgroundColor,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      backgroundColor: kBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Referral Code',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _referralCode ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, color: Colors.black),
                              onPressed: _referralCode == null
                                  ? null
                                  : () {
                                      Clipboard.setData(ClipboardData(text: _referralCode!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Referral code copied to clipboard')),
                                      );
                                    },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _referralCode == null ? null : _shareReferralCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.yellow,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Share Referral Code',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Your Referrals',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You have referred $_referralCount friends',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _firestore.collection('users').doc(_auth.currentUser?.uid).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          }

                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }

                          final data = snapshot.data?.data() as Map<String, dynamic>?;
                          final latestReferralCount = data?['referralCount'] ?? 0;

                          if (latestReferralCount != _referralCount) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                _referralCount = latestReferralCount;
                              });
                            });
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ),
    );
  }
}