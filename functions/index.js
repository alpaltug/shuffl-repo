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
      const rideId = notification.rideId;
      const newUid = notification.newUid; 
    
      const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
      const dropoffLocations = rideDoc.data().dropoffLocations || {};
    
      const dropoffLocation = dropoffLocations[newUid] || 'Unknown Location';
    
      payload = {
        notification: {
          title: "New Ride Participant",
          body: `@${notification.newUsername} has joined the waiting room`,
        },
        data: {
          type: "new_participant",
          rideId: rideId,
          dropoffLocation: dropoffLocation,
          newUsername: notification.newUsername,
        },
      };
    }

    if (payload && tokens.length > 0) {
      try {
        const response = await admin.messaging().sendEachForMulticast({ tokens, ...payload });
        console.log('Notification sent successfully:', response);
      } catch (error) {
        console.error('Error sending notification:', error);
      }
    }
  });

  exports.sendChatMessageNotification = regionalFunctions.firestore
  .document("users/{userId}/chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const senderId = messageData.senderId;
    const content = messageData.content;
    const chatId = context.params.chatId;

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderUsername = senderDoc.data().username || 'Unknown User';

    const chatDoc = await admin.firestore().collection('users').doc(senderId).collection('chats').doc(chatId).get();
    const participants = chatDoc.data().participants || [];

    participants.forEach(async (recipientId) => {
      if (recipientId !== senderId) {
        const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
        const tokens = recipientDoc.data().fcmTokens || [];

        if (tokens.length > 0) {
          const payload = {
            notification: {
              title: `@${senderUsername}`,
              body: content,
            },
            data: {
              type: 'chat_message',
              chatId: chatId,
              senderId: senderId,
            },
          };

          try {
            const response = await admin.messaging().sendEachForMulticast({ tokens, ...payload });
            console.log(`Notification sent to ${recipientId}:`, response);
          } catch (error) {
            console.error(`Error sending notification to ${recipientId}:`, error);
          }
        }
      }
    });
  });

  exports.sendRideGroupChatNotification = regionalFunctions.firestore
  .document("{collectionId}/{rideId}/groupChat/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const senderId = messageData.senderId;
    const content = messageData.content;
    const collectionId = context.params.collectionId; // rides active_rides difference
    const rideId = context.params.rideId;

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderUsername = senderDoc.data().username || 'Unknown User';

    const rideDoc = await admin.firestore().collection(collectionId).doc(rideId).get();
    const participants = rideDoc.data().participants || [];

    participants.forEach(async (participantId) => {
      if (participantId !== senderId) {
        const recipientDoc = await admin.firestore().collection('users').doc(participantId).get();
        const tokens = recipientDoc.data().fcmTokens || [];

        if (tokens.length > 0) {
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

          try {
            const response = await admin.messaging().sendEachForMulticast({ tokens, ...payload });
            console.log(`Notification sent to ${participantId}:`, response);
          } catch (error) {
            console.error(`Error sending notification to ${participantId}:`, error);
          }
        }
      }
    });
  });

  exports.deleteRideNotifications = regionalFunctions.firestore
  .document('active_rides/{rideId}')
  .onCreate(async (snap, context) => {
    const rideId = context.params.rideId;

    const usersSnapshot = await admin.firestore().collection('users').get();

    const batch = admin.firestore().batch();

    for (const userDoc of usersSnapshot.docs) {
      const notificationsRef = userDoc.ref.collection('notifications');
      const notificationsSnapshot = await notificationsRef
        .where('rideId', '==', rideId)
        .get();

      notificationsSnapshot.forEach((notificationDoc) => {
        batch.delete(notificationDoc.ref);
      });
    }

    await batch.commit();
    console.log(`Notifications related to rideId ${rideId} have been deleted.`);
  });
