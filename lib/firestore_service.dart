import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addUser(String? userId, String email) {
    return _db.collection('users').doc(userId).set({
      'email': email,
    });
  }
}