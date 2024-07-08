import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addUser(String? userId, String email) {
    return _db.collection('users').doc(userId).set({
      'email': email,
    });
  }

  Future<void> updateUserProfile(String uid, String fullName, String phoneNumber, String description, [String? imageUrl]) async {
    Map<String, dynamic> data = {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'description': description,
      'imageUrl': imageUrl != null && imageUrl.isNotEmpty ? imageUrl : null,
    };

    await _db.collection('users').doc(uid).update(data);
  }
}