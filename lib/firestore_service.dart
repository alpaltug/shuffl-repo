import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addUser(String uid, String email, {String? name}) async {
  String domain = _extractDomainFromEmail(email);
  bool isStudent = domain.endsWith('.edu');

  await _db.collection('users').doc(uid).set({
    'email': email,
    'name': name ?? '', 
    'createdAt': FieldValue.serverTimestamp(),
    'domain': domain,
    'isStudent': isStudent,
    'rating': null,
    'numRides': 0,
    'preferences': {
      'ageRange': {'min': 18, 'max': 80},
      'schoolToggle': false,
      'sameGenderToggle': false,
      'minCarCapacity': 2,
      'maxCarCapacity': 5,
    },
    'friends': [], 
    'tags': [], 
  });
}

  Future<void> updateUserProfile(
    String uid,
    String fullName,
    String username,
    String description,
    String? imageUrl,
    String sexAssignedAtBirth,
    int age, {
    String goOnline = "offline",
  }) async {
    await _db.collection('users').doc(uid).update({
      'fullName': fullName,
      'username': username,
      'description': description,
      'imageUrl': imageUrl,
      'sexAssignedAtBirth': sexAssignedAtBirth,
      'age': age,
      'goOnline': goOnline,
    });
  }

  Future<bool> checkIfUserExists(String uid) async {
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    return doc.exists;
  }

  Future<bool> checkIfUsernameExists(String username) async {
    final result =
        await _db.collection('users').where('username', isEqualTo: username).get();
    return result.docs.isNotEmpty;
  }

  Future<bool> checkIfEmailExists(String email) async {
    final result =
        await _db.collection('users').where('email', isEqualTo: email).get();
    return result.docs.isNotEmpty;
  }

  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    DocumentReference notificationRef = await _db
        .collection('users')
        .doc(toUid)
        .collection('notifications')
        .add({
      'type': 'friend_request',
      'fromUid': fromUid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await notificationRef.update({'id': notificationRef.id});
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
    await _db
        .collection('users')
        .doc(userUid)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<QuerySnapshot> getUserByUsername(String username) {
    return _db.collection('users').where('username', isEqualTo: username).get();
  }

  String getChatID(String user1, String user2) {
    List<String> participants = [user1, user2];
    participants.sort();
    return participants.join('_');
  }

  Future<void> createChat(String currentUserId, String friendUserId) async {
    String chatId = getChatID(currentUserId, friendUserId);

    DocumentReference chatDocRef = _db
        .collection('users')
        .doc(currentUserId)
        .collection('chats')
        .doc(chatId);

    DocumentSnapshot chatDoc = await chatDocRef.get();
    if (!chatDoc.exists) {
      Map<String, dynamic> chatData = {
        'participants': [currentUserId, friendUserId],
        'lastMessage': {
          'content': '',
          'timestamp': FieldValue.serverTimestamp(),
        },
      };

      await chatDocRef.set(chatData);

      await _db
          .collection('users')
          .doc(friendUserId)
          .collection('chats')
          .doc(chatId)
          .set(chatData);
    }
  }

  Future<void> sendMessage(
    String chatId,
    String currentUserId,
    String friendUserId,
    String messageContent,
    FieldValue timestamp,
  ) async {
    final messageData = {
      'content': messageContent,
      'timestamp': timestamp,
      'senderId': currentUserId,
      'read': currentUserId == friendUserId,
    };

    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    await _db
        .collection('users')
        .doc(friendUserId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      ...messageData,
      'read': false, 
    });

    final lastMessageData = {
      'lastMessage': {
        'content': messageContent,
        'timestamp': timestamp,
      },
      'participants': [currentUserId, friendUserId],
    };

    await _db
        .collection('users')
        .doc(currentUserId)
        .collection('chats')
        .doc(chatId)
        .set(lastMessageData, SetOptions(merge: true));

    await _db
        .collection('users')
        .doc(friendUserId)
        .collection('chats')
        .doc(chatId)
        .set(lastMessageData, SetOptions(merge: true));
  }

  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final unreadMessages = await _db
        .collection('users')
        .doc(userId)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('read', isEqualTo: false)
        .get();

    for (var message in unreadMessages.docs) {
      await message.reference.update({'read': true});
    }
  }

  Future<int> getUnreadMessageSenderCount(String userId) async {
    final chatsSnapshot = await _db
        .collection('users')
        .doc(userId)
        .collection('chats')
        .get();

    Set<String> uniqueSenders = {};
    for (var chatDoc in chatsSnapshot.docs) {
      var messagesSnapshot = await chatDoc.reference
          .collection('messages')
          .where('read', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .get();
      for (var message in messagesSnapshot.docs) {
        uniqueSenders.add(message['senderId']);
      }
    }
    return uniqueSenders.length;
  }

  Future<List<Map<String, dynamic>>> getUsersBySex(String sex) async {
    final result = await _db
        .collection('users')
        .where('sexAssignedAtBirth', isEqualTo: sex)
        .get();
    return result.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getUsersByAgeRange(
      int minAge, int maxAge) async {
    final result = await _db
        .collection('users')
        .where('age', isGreaterThanOrEqualTo: minAge)
        .where('age', isLessThanOrEqualTo: maxAge)
        .get();
    return result.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> getUsersBySchoolDomain(String domain) async {
    final result =
        await _db.collection('users').where('domain', isEqualTo: domain).get();
    return result.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }

  String _extractDomainFromEmail(String email) {
    final RegExp regExp = RegExp(r'@([a-zA-Z0-9.-]+)$');
    final match = regExp.firstMatch(email);
    final domain = match != null ? match.group(1) ?? '' : '';
    return domain;
  }

  Future<void> updateUserRating(String userId, double newRating) async {
    DocumentReference userRef = _db.collection('users').doc(userId);
    DocumentSnapshot userSnapshot = await userRef.get();

    if (userSnapshot.exists) {
      Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;
      double currentRating = userData['rating'] ?? 0.0;
      int numRides = userData['numRides'] ?? 0;

      double updatedRating =
          (currentRating * numRides + newRating) / (numRides + 1);
      int updatedNumRides = numRides + 1;

      await userRef.update({
        'rating': updatedRating,
        'numRides': updatedNumRides,
      });
    }
  }

  Future<Map<String, dynamic>> getUserData(String uid) async {
    DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
    return userDoc.data() as Map<String, dynamic>;
  }

  Future<String?> getUserImageUrl(String uid) async {
    DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
    String? imageUrl = (userDoc.data() as Map<String, dynamic>)['imageUrl'] as String?;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Uri.encodeFull(imageUrl);
    }

    return null;
  }

  Future<String> getUserUsername(String uid) async {
    DocumentSnapshot userDoc = await _db.collection('users').doc(uid).get();
    return (userDoc.data() as Map<String, dynamic>)['username'] as String? ?? 'Unknown';
  }

  Future<List<String>> getParticipantUsernames(List<String> participants) async {
    List<String> usernames = [];
    for (String uid in participants) {
      String username = await getUserUsername(uid);
      usernames.add(username);
    }
    return usernames;
  }

  Future<String?> getFirstParticipantImageUrl(
      List<String> participants, String currentUserUid) async {
    for (String uid in participants) {
      if (uid != currentUserUid) {
        String? imageUrl = await getUserImageUrl(uid);
        if (imageUrl != null) {
          return imageUrl;
        }
      }
    }
    return null;
  }
}