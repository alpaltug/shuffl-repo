const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

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
