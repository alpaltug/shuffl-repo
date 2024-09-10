const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendNotification = functions.firestore
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
            title: "Friend Request",
            body: `${fromUserDoc.data().username} sent you a friend request`,
          },
          data: {
            type: "friend_request",
            fromUid: notification.fromUid,
          },
        };
      }
      // Add more notification types here as needed
      // else if (notification.type === "another_type") { ... }

      if (payload && tokens.length > 0) {
        try {
          const response = await admin.messaging().sendToDevice(tokens, payload);
          console.log('Notification sent successfully:', response);
        } catch (error) {
          console.error('Error sending notification:', error);
        }
      }
    });

// You can add more Cloud Functions here as needed

exports.sendFriendRequestNotification = functions.firestore
    .document("users/{userId}/notifications/{notificationId}")
    .onCreate(async (snap, context) => {
      const notification = snap.data();
      if (notification.type === "friend_request") {
        const toUserDoc = await admin.firestore().collection("users").
            doc(context.params.userId).get();
        const fromUserDoc = await admin.firestore().collection("users").
            doc(notification.fromUid).get();

        const payload = {
          notification: {
            title: "Friend Request",
            body: `${fromUserDoc.data().username} sent you a friend request`,
          },
        };

        const tokens = toUserDoc.data().fcmTokens || [];

        if (tokens.length > 0) {
          await admin.messaging().sendToDevice(tokens, payload);
        }
      }
    });