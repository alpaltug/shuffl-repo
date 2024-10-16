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

        const uniqueTokens = Array.from(new Set(tokens));

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

        if (payload && uniqueTokens.length > 0) {
        try {
            const response = await admin.messaging().sendMulticast({
            tokens: uniqueTokens,
            notification: payload.notification,
            data: payload.data,
            });

            const tokensToRemove = [];
            response.responses.forEach((res, idx) => {
            if (!res.success) {
                const errorCode = res.error.code;
                if (errorCode === 'messaging/invalid-registration-token' ||
                    errorCode === 'messaging/registration-token-not-registered') {
                tokensToRemove.push(uniqueTokens[idx]);
                }
            }
            });

            if (tokensToRemove.length > 0) {
            await admin.firestore().collection('users').doc(userId).update({
                fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
            });
            }

            console.log('Notification sent successfully:', response);
        } catch (error) {
            console.error('Error sending notification:', error);
        }
    }
});

exports.sendChatMessageNotification = regionalFunctions.firestore
  .document("users/{userId}/chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    try {
        const messageRef = snap.ref;
        const messageData = snap.data();
        const senderId = messageData.senderId;
        const content = messageData.content;
        const chatId = context.params.chatId;
        const userId = context.params.userId;

        const notificationId = `${chatId}_${context.params.messageId}`;
        const notificationLogRef = admin.firestore().collection('notifications_log').doc(notificationId);

        console.log(`Checking if notification already exists for notificationId: ${notificationId}`);

        // Run a transaction to ensure atomicity for both the notification flag and logging
        await admin.firestore().runTransaction(async (transaction) => {
            const notificationLogDoc = await transaction.get(notificationLogRef);
            
            // Check if the notification log already exists
            if (notificationLogDoc.exists) {
                console.log(`Notification for ${notificationId} already logged. Skipping.`);
                return;
            }

            const messageSnapshot = await transaction.get(messageRef);
            const messageData = messageSnapshot.data();

            // Check if notification was already sent inside the transaction
            if (messageData.notificationSent) {
                console.log('Notification already sent for this message. Skipping.');
                return;
            }

            // ** Set notificationSent flag in the message and log notification in the transaction **
            transaction.update(messageRef, { notificationSent: true });
            transaction.set(notificationLogRef, {
                chatId: chatId,
                messageId: context.params.messageId,
                senderId: senderId,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log("Notification sent flag marked as true in transaction.");
            console.log("Notification log created for id: " + notificationId);

            console.log(`Processing message from senderId: ${senderId} in chatId: ${chatId} for userId: ${userId}`);

            const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
            const senderUsername = senderDoc.data().username || 'Unknown User';
            console.log("Message sender username is: " + senderUsername);

            const chatDoc = await admin.firestore().collection('users').doc(userId).collection('chats').doc(chatId).get();

            if (!chatDoc.exists) {
                console.error(`Chat document not found for userId ${userId} and chatId ${chatId}`);
                return;
            }

            const participants = chatDoc.data().participants || [];
            console.log(`Participants in the chat: ${participants}`);

            let allTokens = new Set();
            for (const recipientId of participants) {
                if (recipientId !== senderId) {
                    const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
                    const tokens = recipientDoc.data().fcmTokens || [];
                    tokens.forEach(token => allTokens.add(token));
                }
            }

            const senderTokens = senderDoc.data().fcmTokens || [];
            console.log("Sender tokens are: " + JSON.stringify(senderTokens));
            console.log("All tokens are: " + JSON.stringify(Array.from(allTokens)));

            const tokensArray = Array.from(allTokens);
            console.log(`Final tokens to send notification to: ${tokensArray}`);

            if (tokensArray.length > 0) {
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
                        if (errorCode === 'messaging/invalid-registration-token' || errorCode === 'messaging/registration-token-not-registered') {
                            tokensToRemove.push(tokensArray[idx]);
                        }
                    }
                });

                if (tokensToRemove.length > 0) {
                    console.log(`Removing invalid tokens: ${tokensToRemove}`);
                    for (const token of tokensToRemove) {
                        for (const recipientId of participants) {
                            if (recipientId !== senderId) {
                                await admin.firestore().collection('users').doc(recipientId).update({
                                    fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
                                });
                            }
                        }
                    }
                }

                console.log('Notification sent successfully.');
            } else {
                console.log('No tokens to send notification to.');
            }
        });
    } catch (error) {
        console.error('Error in sendChatMessageNotification:', error);
    }
});











exports.sendRideGroupChatNotification = regionalFunctions.firestore
  .document("{collectionId}/{rideId}/groupChat/{messageId}")
  .onCreate(async (snap, context) => {
    const messageData = snap.data();
    const senderId = messageData.senderId;
    const content = messageData.content;
    const collectionId = context.params.collectionId; // 'rides' or 'active_rides'
    const rideId = context.params.rideId;

    // Fetch the timestamp of the last notification
    const lastNotificationTime = messageData.notificationSentAt ? messageData.notificationSentAt.toMillis() : 0;
    const currentTime = Date.now();
    const timeThreshold = 5000; // 5 seconds threshold to prevent duplicate notifications

    // If the last notification was sent less than 5 seconds ago, do not send another notification
    if (lastNotificationTime && (currentTime - lastNotificationTime < timeThreshold)) {
      console.log('Notification already sent recently, skipping.');
      return;
    }

    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    const senderUsername = senderDoc.data().username || 'Unknown User';

    // Fetch the ride document from the appropriate collection
    const rideDoc = await admin.firestore().collection(collectionId).doc(rideId).get();
    
    if (!rideDoc.exists) {
      console.error(`Ride document not found in ${collectionId} for rideId ${rideId}`);
      return;
    }

    const participants = rideDoc.data().participants || [];

    let allTokens = new Set();

    for (const participantId of participants) {
      if (participantId !== senderId) {
        const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
        const tokens = recipientDoc.data().fcmTokens || [];
        tokens.forEach(token => allTokens.add(token));
      }
    }

    const tokensArray = Array.from(allTokens);

    if (tokensArray.length > 0) {
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
        const response = await admin.messaging().sendMulticast({
          tokens: tokensArray,
          notification: payload.notification,
          data: payload.data,
        });

        const tokensToRemove = [];
        response.responses.forEach((res, idx) => {
          if (!res.success) {
            const errorCode = res.error.code;
            if (errorCode === 'messaging/invalid-registration-token' ||
                errorCode === 'messaging/registration-token-not-registered') {
              tokensToRemove.push(tokensArray[idx]);
            }
          }
        });

        for (const token of tokensToRemove) {
          for (const participantId of participants) {
            if (participantId !== senderId) {
              await admin.firestore().collection('users').doc(participantId).update({
                fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
              });
            }
          }
        }

        // Update the message document with the current time to prevent duplicate notifications
        await snap.ref.update({
          notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log('Notification sent successfully:', response);
      } catch (error) {
        console.error('Error sending notification:', error);
      }
    }
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

exports.cleanUpTokensMonthly = regionalFunctions.pubsub
  .schedule('0 0 1 * *') // Runs on 1st day of every month at midnight
  .onRun(async (context) => {
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
  });
