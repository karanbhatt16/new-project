const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Games: Two Truths & One Lie
exports.gamesTwoTruths = require('./games_two_truths');

// ===========================
// Voice Call Push Notification
// ===========================
// Triggered when a new call document is created.
// Sends a push notification to the callee to show incoming call UI.
exports.onCallCreated = functions.firestore
  .document('calls/{callId}')
  .onCreate(async (snapshot, context) => {
    const callData = snapshot.data();
    const callId = context.params.callId;

    if (!callData || callData.status !== 'ringing') {
      return null;
    }

    const calleeUid = callData.calleeUid;
    const callerUid = callData.callerUid;

    // Get callee's FCM token
    const calleeDoc = await admin.firestore().collection('users').doc(calleeUid).get();
    const fcmToken = calleeDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${calleeUid}`);
      return null;
    }

    // Get caller's name
    const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
    const callerName = callerDoc.data()?.username || 'Someone';

    // Send high-priority push notification
    const message = {
      token: fcmToken,
      data: {
        type: 'incoming_call',
        callId: callId,
        callerUid: callerUid,
        callerName: callerName,
      },
      android: {
        priority: 'high',
        ttl: 30000, // 30 seconds
      },
      apns: {
        headers: {
          'apns-priority': '10',
          'apns-push-type': 'voip',
        },
        payload: {
          aps: {
            contentAvailable: true,
            sound: 'default',
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`Push notification sent for call ${callId} to user ${calleeUid}`);
    } catch (error) {
      console.error('Error sending push notification:', error);
    }

    return null;
  });

// Triggered when a call is updated (ended, rejected, etc.)
// Sends a push to dismiss the incoming call UI.
exports.onCallUpdated = functions.firestore
  .document('calls/{callId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const callId = context.params.callId;

    // Only notify if status changed from ringing to something else
    if (beforeData.status === 'ringing' && afterData.status !== 'ringing') {
      const calleeUid = afterData.calleeUid;

      // Get callee's FCM token
      const calleeDoc = await admin.firestore().collection('users').doc(calleeUid).get();
      const fcmToken = calleeDoc.data()?.fcmToken;

      if (!fcmToken) {
        return null;
      }

      // Send notification to dismiss call
      const message = {
        token: fcmToken,
        data: {
          type: 'call_ended',
          callId: callId,
          status: afterData.status,
        },
        android: {
          priority: 'high',
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
        },
      };

      try {
        await admin.messaging().send(message);
        console.log(`Call ended notification sent for call ${callId}`);
      } catch (error) {
        console.error('Error sending call ended notification:', error);
      }
    }

    return null;
  });

// ===========================
// Message Push Notification
// ===========================
// Triggered when a new message is created in a thread.
// Sends a push notification to the recipient.
exports.onMessageCreated = functions.firestore
  .document('threads/{threadId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const messageData = snapshot.data();
    const threadId = context.params.threadId;

    if (!messageData) {
      return null;
    }

    const senderUid = messageData.fromUid;
    const messageText = messageData.text || '';
    const messageType = messageData.type || 'text';

    // Get thread to find the recipient
    const threadDoc = await admin.firestore().collection('threads').doc(threadId).get();
    if (!threadDoc.exists) {
      return null;
    }

    const threadData = threadDoc.data();
    const recipientUid = threadData.userAUid === senderUid ? threadData.userBUid : threadData.userAUid;

    // Get recipient's FCM token
    const recipientDoc = await admin.firestore().collection('users').doc(recipientUid).get();
    const fcmToken = recipientDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${recipientUid}`);
      return null;
    }

    // Get sender's name
    const senderDoc = await admin.firestore().collection('users').doc(senderUid).get();
    const senderName = senderDoc.data()?.username || 'Someone';

    // Prepare notification body based on message type
    let body = messageText;
    if (messageType === 'image') {
      body = '📷 Sent a photo';
    } else if (messageType === 'call') {
      body = '📞 Call';
    } else if (messageText.length > 100) {
      body = messageText.substring(0, 100) + '...';
    }

    // Send push notification
    const message = {
      token: fcmToken,
      notification: {
        title: senderName,
        body: body,
      },
      data: {
        type: 'new_message',
        threadId: threadId,
        senderUid: senderUid,
        senderName: senderName,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'messages',
          icon: 'ic_notification',
          color: '#FF4B6E',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`Message notification sent to user ${recipientUid}`);
    } catch (error) {
      console.error('Error sending message notification:', error);
    }

    return null;
  });

// ===========================
// Friend Request Push Notification
// ===========================
// Triggered when a new friend request is created.
exports.onFriendRequestCreated = functions.firestore
  .document('users/{userId}/incoming/{fromUid}')
  .onCreate(async (snapshot, context) => {
    const userId = context.params.userId;
    const fromUid = context.params.fromUid;

    // Get recipient's FCM token
    const recipientDoc = await admin.firestore().collection('users').doc(userId).get();
    const fcmToken = recipientDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${userId}`);
      return null;
    }

    // Get sender's name
    const senderDoc = await admin.firestore().collection('users').doc(fromUid).get();
    const senderName = senderDoc.data()?.username || 'Someone';

    // Send push notification
    const message = {
      token: fcmToken,
      notification: {
        title: 'New Friend Request',
        body: `${senderName} sent you a friend request`,
      },
      data: {
        type: 'friend_request',
        fromUid: fromUid,
        fromName: senderName,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'social',
          icon: 'ic_notification',
          color: '#FF4B6E',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`Friend request notification sent to user ${userId} from ${senderName}`);
    } catch (error) {
      console.error('Error sending friend request notification:', error);
    }

    return null;
  });

// ===========================
// Friend Request Accepted Push Notification
// ===========================
// Triggered when someone accepts a friend request (added to friends collection).
exports.onFriendAdded = functions.firestore
  .document('users/{userId}/friends/{friendUid}')
  .onCreate(async (snapshot, context) => {
    const userId = context.params.userId;
    const friendUid = context.params.friendUid;

    // We want to notify the person who originally sent the request
    // The friendUid is the one who accepted, so notify them that userId accepted
    // Actually, when A accepts B's request, both get added to each other's friends
    // We should notify the original requester

    // Get the friend's FCM token (the one who will receive the notification)
    const friendDoc = await admin.firestore().collection('users').doc(friendUid).get();
    const fcmToken = friendDoc.data()?.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${friendUid}`);
      return null;
    }

    // Get the user's name who accepted
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userName = userDoc.data()?.username || 'Someone';

    // Send push notification
    const message = {
      token: fcmToken,
      notification: {
        title: 'Friend Request Accepted! 🎉',
        body: `${userName} accepted your friend request`,
      },
      data: {
        type: 'friend_accepted',
        userId: userId,
        userName: userName,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'social',
          icon: 'ic_notification',
          color: '#4CAF50',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
      console.log(`Friend accepted notification sent to user ${friendUid}`);
    } catch (error) {
      console.error('Error sending friend accepted notification:', error);
    }

    return null;
  });

// ===========================
// Thread Deletion
// ===========================
// Callable: deleteThreadRecursive({ threadId })
// Deletes /threads/{threadId} and its /messages subcollection.
exports.deleteThreadRecursive = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  const threadId = data && data.threadId;
  if (!threadId || typeof threadId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'threadId is required');
  }

  const db = admin.firestore();
  const threadRef = db.collection('threads').doc(threadId);
  const threadSnap = await threadRef.get();
  if (!threadSnap.exists) {
    return { ok: true, deleted: false };
  }

  const t = threadSnap.data();
  const uid = context.auth.uid;
  const isMember = t.userAUid === uid || t.userBUid === uid;
  if (!isMember) {
    throw new functions.https.HttpsError('permission-denied', 'Not a thread member');
  }

  // Best-effort: delete messages in batches.
  const messagesRef = threadRef.collection('messages');
  while (true) {
    const snap = await messagesRef.limit(500).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();
  }

  await threadRef.delete();
  return { ok: true, deleted: true };
});
