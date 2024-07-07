import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addUser(String? userId, String email) {
    return _db.collection('users').doc(userId).set({
      'email': email,
    });
  }
    Future<void> updateUserProfile(String uid, String fullName, String phoneNumber, String description) async {
    await _db.collection('users').doc(uid).update({
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'description': description,
    });
  }
}
