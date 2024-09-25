const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const regionalFunctions = functions.region('us-west2');
exports.sendNotification = regionalFunctions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = context.params.userId;

    const toUserDoc = await admin.firestore().collection("users").doc(userId).get();
    const tokens = toUserDoc.data().fcmTokens || [];

    let payload;

    if (notification.type === "friend_request") {
      const fromUserDoc = await admin.firestore().collection("users").doc(notification.fromUid).get();
      payload = {
        notification: {
          title: "New Friend Request",
          body: `${fromUserDoc.data().username} sent you a friend request`,
        },
        data: {
          type: "friend_request",
          fromUid: notification.fromUid,
        },
      };
    } else if (notification.type === "new_participant") {
      payload = {
        notification: {
          title: "New Ride Participant",
          body: `@${notification.newUsername} has joined the waiting room`,
        },
        data: {
          type: "new_participant",
          rideId: notification.rideId,
        },
      };
    }

    if (payload && tokens.length > 0) {
      try {
        const response = await admin.messaging().sendMulticast({ tokens, ...payload });
        console.log('Notification sent successfully:', response);
      } catch (error) {
        console.error('Error sending notification:', error);
      }
    }
  });

exports.sendFriendRequestNotification = regionalFunctions.https.onCall(async (data, context) => {
  // Check if the user is authenticated
  if (!context.auth) {
    console.log('Unauthenticated user attempted to call function');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to send a friend request.');
  }

  const { toUserId, fromUserId, fromUsername } = data;

  await admin.firestore().collection('users').doc(toUserId).collection('notifications').add({
    type: 'friend_request',
    fromUid: fromUserId,
    fromUsername: fromUsername,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  const userDoc = await admin.firestore().collection('users').doc(toUserId).get();
  const fcmTokens = userDoc.data().fcmTokens || [];
  const message = {
    notification: {
      title: 'New Friend Request',
      body: `${fromUsername} sent you a friend request`,
    },
    data: {
      type: 'friend_request',
      fromUserId: fromUserId,
    },
    tokens: fcmTokens,
  };

  try {
    const response = await admin.messaging().sendMulticast(message);
    console.log('Successfully sent message:', response);
    return { success: true };
  } catch (error) {
    console.log('Error sending message:', error);
    throw new functions.https.HttpsError('internal', 'Error sending notification');
  }
});


exports.sendNewParticipantNotification = regionalFunctions.https.onCall(async (data, context) => {
  if (!context.auth) {
    console.log('Unauthenticated user attempted to call function');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to send a notification.');
  }

  const { toUserId, newUsername, rideId } = data;

  await admin.firestore().collection('users').doc(toUserId).collection('notifications').add({
    type: 'new_participant',
    newUsername: newUsername,
    rideId: rideId,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  const userDoc = await admin.firestore().collection('users').doc(toUserId).get();
  const fcmTokens = userDoc.data().fcmTokens || [];

  const message = {
    notification: {
      title: 'New Ride Participant',
      body: `@${newUsername} has joined the waiting room`,
    },
    data: {
      type: 'new_participant',
      rideId: rideId,
    },
    tokens: fcmTokens,
  };

  try {
    const response = await admin.messaging().sendMulticast(message);
    console.log('Successfully sent message:', response);
    return { success: true };
  } catch (error) {
    console.log('Error sending message:', error);
    throw new functions.https.HttpsError('internal', 'Error sending notification');
  }
});

// Function for generating referral code
exports.generateReferralCode = regionalFunctions.https.onCall(async (data, context) => {
  if (!context.auth) {
    console.log('Unauthenticated user attempted to call function');
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated to generate a referral code.');
  }

  const userId = context.auth.uid;
  let referralCode;

  await admin.firestore().runTransaction(async (transaction) => {
    let isUnique = false;
    while (!isUnique) {
      referralCode = generateCode();
      const snapshot = await transaction.get(
        admin.firestore().collection('users').where('referralCode', '==', referralCode)
      );
      if (snapshot.empty) {
        isUnique = true;
        transaction.update(admin.firestore().collection('users').doc(userId), {
          referralCode: referralCode,
          referralCount: admin.firestore.FieldValue.increment(0),
        });
      }
    }
  });

  return { referralCode: referralCode };
});

function generateCode() {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < 6; i++) {
    result += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return result;
}