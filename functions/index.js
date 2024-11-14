const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const regionalFunctions = functions.region('us-west2');


// Notification for Friend Requests and New Participants
exports.sendNotification = regionalFunctions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = context.params.userId;

    const toUserDoc = await admin.firestore().collection("users").doc(userId).get();
    const tokens = toUserDoc.data().fcmTokens || [];

    const uniqueTokens = Array.from(new Set(tokens));

    let payload;

    if (notification.type === "friend_request") {
      const fromUserDoc = await admin.firestore().collection("users").doc(notification.fromUid).get();
      const fromUsername = fromUserDoc.data().username || 'Someone';

      payload = {
        notification: {
          title: "New Friend Request",
          body: `${fromUsername} sent you a friend request`,
        },
        data: {
          type: "friend_request",
          fromUid: notification.fromUid,
        },
      };
    } else if (notification.type === "new_participant") {
      const rideId = notification.rideId;
      const newUid = notification.newUid;

      const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
      const dropoffLocations = rideDoc.data().dropoffLocations || {};

      const dropoffLocation = dropoffLocations[newUid] || 'Unknown Location';
      const newUsername = notification.newUsername || 'A participant';

      payload = {
        notification: {
          title: "New Ride Participant",
          body: `@${newUsername} has joined the waiting room`,
        },
        data: {
          type: "new_participant",
          rideId: rideId,
          dropoffLocation: dropoffLocation,
          newUsername: newUsername,
        },
      };
    }

    if (payload && uniqueTokens.length > 0) {
      try {
        const response = await admin.messaging().sendEachForMulticast({
          tokens: uniqueTokens,
          notification: payload.notification,
          data: payload.data,
        });

        const tokensToRemove = [];
        response.responses.forEach((res, idx) => {
          if (!res.success) {
            const errorCode = res.error.code;
            if (
              errorCode === 'messaging/invalid-registration-token' ||
              errorCode === 'messaging/registration-token-not-registered'
            ) {
              tokensToRemove.push(uniqueTokens[idx]);
            }
          }
        });

        if (tokensToRemove.length > 0) {
          await admin.firestore().collection('users').doc(userId).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
          });
          console.log(`Removed invalid tokens for user ${userId}: ${tokensToRemove}`);
        }

        console.log('Notification sent successfully:', response);
      } catch (error) {
        console.error('Error sending notification:', error);
      }
    }
  });

 // Notifications for One-on-One Chats (`user_chats`)
exports.sendUserChatMessageNotification = regionalFunctions.firestore
  .document("user_chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    await sendChatMessageNotificationHandler(snap, context, 'user');
  });


 // Notifications for Referral Chats (`referral_chats`)
exports.sendReferralChatMessageNotification = regionalFunctions.firestore
  .document("referral_chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    await sendChatMessageNotificationHandler(snap, context, 'referral');
  });


 // Notifications for Group Chats in Rides (`rides` and `active_rides`)
exports.sendRideGroupChatNotification = regionalFunctions.firestore
  .document("rides/{rideId}/groupChat/{messageId}")
  .onCreate(async (snap, context) => {
    await sendRideGroupChatNotificationHandler(snap, context, 'rides');
  });

// Trigger: When a new message is added under active_rides/{rideId}/groupChat/{messageId}
exports.sendActiveRideGroupChatNotification = regionalFunctions.firestore
  .document("active_rides/{rideId}/groupChat/{messageId}")
  .onCreate(async (snap, context) => {
    await sendRideGroupChatNotificationHandler(snap, context, 'active_rides');
  });


async function sendChatMessageNotificationHandler(snap, context, chatType) {
  try {
    const messageRef = snap.ref;
    const messageData = snap.data();
    const senderId = messageData.senderId;
    const content = messageData.content;
    const chatId = context.params.chatId;

    if (messageData.notificationSent) {
      console.log('Notification already sent for this message. Skipping.');
      return;
    }

    await messageRef.update({ notificationSent: true });

    const chatDoc = await admin.firestore().collection(`${chatType}_chats`).doc(chatId).get();

    if (!chatDoc.exists) {
      console.error(`Chat document not found in ${chatType}_chats for chatId ${chatId}`);
      return;
    }

    const participants = chatDoc.data().participants || [];

    const recipientIds = participants.filter(uid => uid !== senderId);

    if (recipientIds.length === 0) {
      console.log('No recipients found for this message.');
      return;
    }

    let allTokens = new Set();
    for (const recipientId of recipientIds) {
      const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
      const tokens = recipientDoc.data().fcmTokens || [];
      tokens.forEach(token => allTokens.add(token));
    }

    const tokensArray = Array.from(allTokens);

    if (tokensArray.length === 0) {
      console.log('No valid FCM tokens found for recipients.');
      return;
    }

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderUsername = senderDoc.data().username || 'Unknown User';

    const payload = {
      notification: {
        title: `@${senderUsername}`,
        body: content,
      },
      data: {
        type: 'chat_message',
        chatType: chatType,
        chatId: chatId,
        senderId: senderId,
      },
    };

    console.log('Sending payload:', JSON.stringify(payload));

    const response = await admin.messaging().sendEachForMulticast({
      tokens: tokensArray,
      notification: payload.notification,
      data: payload.data,
    });

    console.log('FCM response:', JSON.stringify(response));

    const tokensToRemove = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const errorCode = res.error.code;
        console.error(`Error sending to token ${tokensArray[idx]}:`, res.error);
        if (
          errorCode === 'messaging/invalid-registration-token' ||
          errorCode === 'messaging/registration-token-not-registered'
        ) {
          tokensToRemove.push(tokensArray[idx]);
        }
      }
    });

    if (tokensToRemove.length > 0) {
      console.log(`Removing invalid tokens: ${tokensToRemove}`);
      for (const recipientId of recipientIds) {
        await admin.firestore().collection('users').doc(recipientId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
        });
      }
    }

    console.log('Chat message notification sent successfully.');
  } catch (error) {
    console.error('Error in sendChatMessageNotificationHandler:', error);
  }
}

async function sendRideGroupChatNotificationHandler(snap, context, collectionId) {
  try {
    const messageRef = snap.ref;
    const messageData = snap.data();
    const senderId = messageData.senderId;
    const content = messageData.content;
    const rideId = context.params.rideId;

    if (messageData.notificationSent) {
      console.log('Notification already sent for this message. Skipping.');
      return;
    }

    await messageRef.update({ notificationSent: true });

    const rideDoc = await admin.firestore().collection(collectionId).doc(rideId).get();

    if (!rideDoc.exists) {
      console.error(`Ride document not found in ${collectionId} for rideId ${rideId}`);
      return;
    }

    const participants = rideDoc.data().participants || [];

    const recipientIds = participants.filter(uid => uid !== senderId);

    if (recipientIds.length === 0) {
      console.log('No recipients found for this group chat message.');
      return;
    }

    let allTokens = new Set();
    for (const recipientId of recipientIds) {
      const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
      const tokens = recipientDoc.data().fcmTokens || [];
      tokens.forEach(token => allTokens.add(token));
    }

    const tokensArray = Array.from(allTokens);

    if (tokensArray.length === 0) {
      console.log('No valid FCM tokens found for recipients in group chat.');
      return;
    }

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderUsername = senderDoc.data().username || 'Unknown User';

    const payload = {
      notification: {
        title: `@${senderUsername}`,
        body: content,
      },
      data: {
        type: 'ride_chat_message',
        rideId: rideId,
        senderId: senderId,
      },
    };

    console.log('Sending payload:', JSON.stringify(payload));

    const response = await admin.messaging().sendEachForMulticast({
      tokens: tokensArray,
      notification: payload.notification,
      data: payload.data,
    });

    console.log('FCM response:', JSON.stringify(response));

    const tokensToRemove = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const errorCode = res.error.code;
        console.error(`Error sending to token ${tokensArray[idx]}:`, res.error);
        if (
          errorCode === 'messaging/invalid-registration-token' ||
          errorCode === 'messaging/registration-token-not-registered'
        ) {
          tokensToRemove.push(tokensArray[idx]);
        }
      }
    });

    if (tokensToRemove.length > 0) {
      console.log(`Removing invalid tokens: ${tokensToRemove}`);
      for (const recipientId of recipientIds) {
        await admin.firestore().collection('users').doc(recipientId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
        });
      }
    }

    console.log('Ride group chat notification sent successfully.');
  } catch (error) {
    console.error('Error in sendRideGroupChatNotificationHandler:', error);
  }
}

exports.deleteRideNotifications = regionalFunctions.firestore
  .document('active_rides/{rideId}')
  .onCreate(async (snap, context) => {
    const rideId = context.params.rideId;

    try {
      const usersSnapshot = await admin.firestore().collection('users').get();

      const batch = admin.firestore().batch();

      usersSnapshot.forEach(userDoc => {
        const notificationsRef = userDoc.ref.collection('notifications');
        const query = notificationsRef.where('rideId', '==', rideId);

        query.get().then(notificationsSnapshot => {
          notificationsSnapshot.forEach(notificationDoc => {
            batch.delete(notificationDoc.ref);
          });
        }).catch(error => {
          console.error(`Error fetching notifications for user ${userDoc.id}:`, error);
        });
      });

      await batch.commit();
      console.log(`Notifications related to rideId ${rideId} have been deleted.`);
    } catch (error) {
      console.error('Error deleting ride notifications:', error);
    }
  });


exports.cleanUpTokensMonthly = regionalFunctions.pubsub
  .schedule('0 0 1 * *') 
  .onRun(async (context) => {
    try {
      const usersSnapshot = await admin.firestore().collection('users').get();

      for (const userDoc of usersSnapshot.docs) {
        const tokens = userDoc.data().fcmTokens || [];
        const uniqueTokens = Array.from(new Set(tokens));

        if (tokens.length !== uniqueTokens.length) {
          await userDoc.ref.update({ fcmTokens: uniqueTokens });
          console.log(`Cleaned up duplicate tokens for user ${userDoc.id}`);
        }
      }

      console.log('Monthly token cleanup completed.');
    } catch (error) {
      console.error('Error during monthly token cleanup:', error);
    }
  });