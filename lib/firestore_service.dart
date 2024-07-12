import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addUser(String uid, String email) async {
    await _db.collection('users').doc(uid).set({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUserProfile(
  String uid, String fullName, String username, String description, String? imageUrl, String sexAssignedAtBirth, String birthday) async {
  await _db.collection('users').doc(uid).update({
    'fullName': fullName,
    'username': username,
    'description': description,
    'imageUrl': imageUrl,
    'sexAssignedAtBirth': sexAssignedAtBirth,
    'birthday': birthday,
  });
}

  Future<bool> checkIfUserExists(String uid) async {
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  Future<bool> checkIfUsernameExists(String username) async {
    final result = await _db.collection('users').where('username', isEqualTo: username).get();
    return result.docs.isNotEmpty;
  }
  Future<bool> checkIfEmailExists(String email) async {
    final result = await _db.collection('users').where('email', isEqualTo: email).get();
    return result.docs.isNotEmpty;
  }
  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    await _db.collection('users').doc(toUid).collection('notifications').add({
      'type': 'friend_request',
      'fromUid': fromUid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptFriendRequest(String currentUserUid, String friendUid) async {
    await _db.collection('users').doc(currentUserUid).update({
      'friends': FieldValue.arrayUnion([friendUid]),
    });
    await _db.collection('users').doc(friendUid).update({
      'friends': FieldValue.arrayUnion([currentUserUid]),
    });
  }

  Future<void> declineFriendRequest(String notificationId, String userUid) async {
    await _db.collection('users').doc(userUid).collection('notifications').doc(notificationId).delete();
  }
  Future<QuerySnapshot> getUserByUsername(String username) {
    return _db.collection('users').where('username', isEqualTo: username).get();
  }
}
