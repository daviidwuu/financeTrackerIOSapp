const functions = require('firebase-functions/v1');
const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

// CRITICAL: Use Firebase Admin SDK service account (not Compute Engine default)
setGlobalOptions({
  serviceAccount: 'firebase-adminsdk-fbsvc@financetracker-c628c.iam.gserviceaccount.com'
});

// Initialize Firebase Admin
admin.initializeApp();

// Helper function to get default icon for category
function getIconForCategory(category) {
  const categoryIcons = {
    'Dining': 'fork.knife',
    'Groceries': 'cart.fill',
    'Transportation': 'car.fill',
    'Shopping': 'bag.fill',
    'Entertainment': 'tv.fill',
    'Utilities': 'bolt.fill',
    'Health': 'heart.fill',
    'Salary': 'dollarsign.circle.fill',
    'Freelance': 'laptopcomputer'
  };
  return categoryIcons[category] || 'dollarsign.circle';
}

// Helper function to get default color for category
function getColorForCategory(category) {
  const categoryColors = {
    'Dining': '#FF6B6B',
    'Groceries': '#4ECDC4',
    'Transportation': '#45B7D1',
    'Shopping': '#FFA07A',
    'Entertainment': '#98D8C8',
    'Utilities': '#FFD93D',
    'Health': '#6BCF7F',
    'Salary': '#4CAF50',
    'Freelance': '#2196F3'
  };
  return categoryColors[category] || '#757575';
}

/**
 * Cloud Function to add transactions via Apple Shortcuts
 */
exports.addTransaction = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');

  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.set('Access-Control-Max-Age', '3600');
    res.status(204).send('');
    return;
  }

  // Only allow POST
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { UserID, Data } = req.body;

    // Validate required fields
    if (!UserID || !Data) {
      res.status(400).json({
        error: 'Missing required fields',
        required: { UserID: 'string', Data: { Category: 'string', Type: 'string', Amount: 'number', Notes: 'string' } }
      });
      return;
    }

    const { Category, Type, Amount, Notes } = Data;

    if (!Category || !Type || Amount === undefined) {
      res.status(400).json({
        error: 'Missing required Data fields',
        required: ['Category', 'Type', 'Amount']
      });
      return;
    }

    // Validate amount
    const parsedAmount = parseFloat(Amount);
    if (isNaN(parsedAmount)) {
      res.status(400).json({ error: 'Invalid Amount' });
      return;
    }

    // Prepare transaction data
    const transactionType = Type.toLowerCase();
    const finalAmount = transactionType === 'income'
      ? Math.abs(parsedAmount)
      : -Math.abs(parsedAmount);

    const transactionData = {
      title: Category,
      subtitle: Category,
      amount: finalAmount,
      date: new Date(),
      icon: getIconForCategory(Category),
      colorHex: getColorForCategory(Category),
      note: Notes || null,
      userId: UserID,
      type: transactionType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'shortcuts'
    };

    // Add to Firestore
    const docRef = await admin.firestore()
      .collection('users')
      .doc(UserID)
      .collection('transactions')
      .add(transactionData);

    // Success response
    res.status(200).json({
      success: true,
      message: `Transaction added successfully`,
      transactionId: docRef.id,
      data: {
        amount: finalAmount,
        category: Category,
        type: transactionType
      }
    });

  } catch (error) {
    console.error('Error adding transaction:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

/**
 * Cloud Function to process recurring transactions daily
 * Runs every day at 00:01 UTC
 */
exports.processRecurringTransactions = functions.pubsub.schedule('1 0 * * *').onRun(async (context) => {
  const db = admin.firestore();
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()); // 00:00:00 today

  console.log('Processing recurring transactions for date:', today.toISOString());

  try {
    // Query all recurring transactions using Collection Group Query
    // This finds all documents in any collection named 'recurringTransactions'
    const snapshot = await db.collectionGroup('recurringTransactions').get();

    if (snapshot.empty) {
      console.log('No recurring transactions found.');
      return null;
    }

    const batch = db.batch();
    let operationCount = 0;

    for (const doc of snapshot.docs) {
      const item = doc.data();
      const itemId = doc.id;
      // The parent of 'recurringTransactions' is the user document: users/{userId}
      // doc.ref.parent is the collection, doc.ref.parent.parent is the user doc
      const userRef = doc.ref.parent.parent;
      if (!userRef) continue;
      const userId = userRef.id;

      let nextDueDate;
      let lastProcessed = item.lastProcessedDate ? item.lastProcessedDate.toDate() : null;

      if (lastProcessed) {
        // Calculate next due date based on frequency from last processed date
        nextDueDate = new Date(lastProcessed);
        switch (item.frequency) {
          case "Daily":
            nextDueDate.setDate(nextDueDate.getDate() + 1);
            break;
          case "Weekly":
            nextDueDate.setDate(nextDueDate.getDate() + 7);
            break;
          case "Bi-Weekly":
            nextDueDate.setDate(nextDueDate.getDate() + 14);
            break;
          case "Yearly":
            nextDueDate.setFullYear(nextDueDate.getFullYear() + 1);
            break;
          default: // "Monthly"
            nextDueDate.setMonth(nextDueDate.getMonth() + 1);
            break;
        }
      } else {
        // First time: use startDate
        nextDueDate = item.startDate.toDate();
      }

      // Normalize nextDueDate to Start of Day for comparison
      const nextDueStartOfDay = new Date(nextDueDate.getFullYear(), nextDueDate.getMonth(), nextDueDate.getDate());

      // Check if due (nextDueStartOfDay <= today)
      if (nextDueStartOfDay <= today) {
        console.log(`Processing item ${item.name} for user ${userId}. Due: ${nextDueStartOfDay.toISOString()}`);

        const transactionDate = nextDueStartOfDay; // Use the calculated due date as the transaction date

        // 1. Create the Transaction Data
        // Handle Expense vs Income logic
        let amount = item.amount;
        // Logic from Swift:
        // if item.type == "income" ? amount : -abs(amount)
        const type = item.type || "expense";
        const finalAmount = (type === "income") ? Math.abs(amount) : -Math.abs(amount);

        const newTransactionRef = userRef.collection('transactions').doc();
        const newTransaction = {
          title: item.name,
          subtitle: item.name,
          amount: finalAmount,
          date: admin.firestore.Timestamp.fromDate(transactionDate),
          icon: item.icon,
          colorHex: item.colorHex || '#000000',
          note: `Recurring: ${item.frequency}` + (item.note ? ` - ${item.note}` : ""),
          type: type,
          source: 'recurring',
          userId: userId,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        };

        batch.set(newTransactionRef, newTransaction);

        // 2. Update the RecurringTransaction
        // We set lastProcessedDate to the date we just "paid" for/processed.
        // This ensures the next run calculates from THIS date.
        batch.update(doc.ref, {
          lastProcessedDate: admin.firestore.Timestamp.fromDate(transactionDate)
        });

        operationCount++;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
      console.log(`Successfully processed ${operationCount} recurring transactions.`);
    } else {
      console.log('No recurring transactions due today.');
    }

    return null;

  } catch (error) {
    console.error('Error processing recurring transactions:', error);
    return null;
  }
});

/**
 * Triggered when a new Split Request is created.
 * Notifies the target user (User 2) with push notification.
 * Using Gen 2 with Firebase Admin SDK service account configured via setGlobalOptions()
 */
exports.onSplitRequestCreated = onDocumentCreated(
  'users/{userId}/requests/{requestId}',
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data associated with the event');
      return;
    }

    const request = snap.data();
    const requestId = event.params.requestId;
    const targetUserId = event.params.userId; // User ID from path: users/{userId}/requests/{requestId}

    console.log('Split request created:', requestId, request);
    console.log('Using Service Account for FCM Auth');

    // Get the sender user ID from request data
    const senderUserId = request.requesterId; // iOS model uses 'requesterId' for sender

    // Validate user IDs
    if (!targetUserId) {
      console.error('Target userId missing from path params');
      return;
    }

    if (!senderUserId) {
      console.error('Sender requesterId is missing from request:', request);
      return;
    }

    console.log('Target user:', targetUserId, 'Sender:', senderUserId);

    try {
      console.log('Fetching target user doc for:', targetUserId);
      const targetUserDoc = await admin.firestore()
        .collection('users')
        .doc(targetUserId)
        .get();
      console.log('Generic Firestore fetch complete. Exists:', targetUserDoc.exists);

      if (!targetUserDoc.exists) {
        console.log('Target user not found:', targetUserId);
        return;
      }

      const fcmToken = targetUserDoc.data().fcmToken;
      console.log('FCM Token retrieved:', fcmToken ? 'Yes' : 'No');

      if (!fcmToken) {
        console.log('No FCM token for user:', targetUserId);
        return;
      }

      const senderName = request.requesterName || 'Someone';

      const message = {
        token: fcmToken,
        notification: {
          title: 'Split Request',
          body: `${senderName} wants to split $${Math.abs(request.amount).toFixed(2)} with you`
        },
        data: {
          type: 'split_request',
          requestId: requestId,
          fromUserId: senderUserId,
          amount: String(request.amount)
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      };

      console.log('Attemping to send message payload...');
      const response = await admin.messaging().send(message);
      console.log('Successfully sent notification. MessageID:', response);

    } catch (error) {
      console.error('Error sending notification:', error);
    }
  }
);

/**
 * Triggered when a Split Request is updated (e.g., accepted/declined).
 * Notifies the sender (User 1) about the status change.
 */
exports.onSplitRequestUpdated = onDocumentUpdated(
  'users/{userId}/requests/{requestId}',
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const requestId = event.params.requestId;

    // Only send notification if status changed
    if (beforeData.status === afterData.status) {
      console.log('Status unchanged, skipping notification');
      return;
    }

    console.log('Split request updated:', requestId, 'Status:', afterData.status);

    const senderUserId = afterData.fromUserId; // User 1 (original sender)
    const targetUserId = afterData.userId; // User 2 (responder)

    try {
      // Get sender's FCM token
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderUserId)
        .get();

      if (!senderDoc.exists) {
        console.log('Sender user not found:', senderUserId);
        return;
      }

      const fcmToken = senderDoc.data().fcmToken;
      if (!fcmToken) {
        console.log('No FCM token for user:', senderUserId);
        return;
      }

      // Get responder's name
      const targetDoc = await admin.firestore()
        .collection('users')
        .doc(targetUserId)
        .get();

      const targetName = targetDoc.exists ? (targetDoc.data().name || targetDoc.data().displayName || 'Friend') : 'Someone';

      // Determine notification content based on status
      let title, body;
      if (afterData.status === 'accepted') {
        title = '✅ Split Accepted';
        body = `${targetName} accepted your split request for $${Math.abs(afterData.amount).toFixed(2)}`;
      } else if (afterData.status === 'declined') {
        title = 'Split Declined';
        body = `${targetName} declined the split for $${Math.abs(afterData.amount).toFixed(2)}`;
      } else {
        console.log('Unknown status:', afterData.status);
        return;
      }

      // Send notification
      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body
        },
        data: {
          type: 'split_response',
          requestId: requestId,
          status: afterData.status,
          fromUserId: targetUserId
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      };

      await admin.messaging().send(message);
      console.log('Successfully sent status update notification to:', senderUserId);

    } catch (error) {
      console.error('Error sending notification:', error);
    }
  }
);

/**
 * Triggered when a Transaction is updated.
 * Detects removed splits and deletes corresponding requests.
 */
exports.onTransactionUpdated = onDocumentUpdated(
  'users/{userId}/transactions/{transactionId}',
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const transactionId = event.params.transactionId;
    const senderId = event.params.userId;

    const beforeSplits = beforeData.splits || [];
    const afterSplits = afterData.splits || [];

    // 1. Identify Removed Splits
    const afterSplitIds = new Set(afterSplits.map(s => s.id));
    const removedSplits = beforeSplits.filter(s => !afterSplitIds.has(s.id));

    // Fetch sender details once if needed
    let senderNameVal = 'Friend';
    if (removedSplits.length > 0 || afterSplits.length > beforeSplits.length) {
      const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
      senderNameVal = senderDoc.exists ? (senderDoc.data().name || senderDoc.data().displayName || 'Friend') : 'Friend';
    }

    // Handle Removed Splits
    for (const split of removedSplits) {
      if (split.friendId) {
        const reqId = split.requestId || transactionId;
        await deleteSplitRequest(split.friendId, reqId, senderNameVal, split.amount);
      }
    }

    // 2. Identify Added or Updated Splits
    for (const split of afterSplits) {
      if (!split.friendId) continue;

      const oldSplit = beforeSplits.find(s => s.id === split.id);

      if (!oldSplit || Math.abs(oldSplit.amount - split.amount) > 0.01) {

        const requestData = {
          requesterId: senderId,
          requesterName: senderNameVal,
          amount: split.amount,
          note: afterData.note || afterData.title || 'Split Bill',
          originalTransactionId: transactionId,
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        };

        await admin.firestore()
          .collection('users')
          .doc(split.friendId)
          .collection('requests')
          .doc(transactionId)
          .set(requestData, { merge: true });

        console.log(`Upserted request ${transactionId} for friend ${split.friendId}`);
      }
    }
  }
);

/**
 * Triggered when a Transaction is deleted.
 * Deletes all associated split requests.
 */
exports.onTransactionDeleted = onDocumentDeleted(
  'users/{userId}/transactions/{transactionId}',
  async (event) => {
    const data = event.data.data(); // In delete, data() returns the document before deletion

    if (!data) return;

    const splits = data.splits || [];
    if (splits.length === 0) return;

    const senderId = event.params.userId;
    const senderDoc = await admin.firestore().collection('users').doc(senderId).get();
    const senderNameVal = senderDoc.exists ? (senderDoc.data().name || senderDoc.data().displayName || 'Friend') : 'Friend';

    for (const split of splits) {
      if (split.friendId && split.requestId) {
        await deleteSplitRequest(split.friendId, split.requestId, senderNameVal, split.amount);
      }
    }
  }
);

async function deleteSplitRequest(friendId, transactionId, senderName, amount) {
  try {
    const requestsRef = admin.firestore().collection('users').doc(friendId).collection('requests');

    // Query for ANY request linked to this transaction (handles legacy UUIDs and new transactionId-based docs)
    const snapshot = await requestsRef.where('originalTransactionId', '==', transactionId).get();

    if (snapshot.empty) {
      console.log('No requests found to delete for transaction:', transactionId);
      // Fallback: Check if a doc exists with the exact ID (in case originalTransactionId wasn't set on legacy docs?)
      // Unlikely, but good safety net if we passed explicit ID.
      // But for now, we rely on the query.
      return;
    }

    // Delete all matching requests (should usually be 1)
    const batch = admin.firestore().batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    await batch.commit();

    console.log(`Deleted ${snapshot.size} request(s) for transaction ${transactionId} friend ${friendId}`);

    // Send Notification
    const userDoc = await admin.firestore().collection('users').doc(friendId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (fcmToken) {
      const message = {
        token: fcmToken,
        notification: {
          title: 'Split Removed',
          body: `${senderName} removed the split for $${Math.abs(amount).toFixed(2)}.`
        },
        data: {
          type: 'split_removed',
          requestId: transactionId // Use transactionId as reference
        },
        apns: { payload: { aps: { sound: 'default', badge: 1 } } }
      };
      await admin.messaging().send(message);
      console.log('Sent removal notification to:', friendId);
    }
  } catch (e) {
    console.error('Error deleting split request:', e);
  }
}
