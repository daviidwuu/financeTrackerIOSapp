const functions = require('firebase-functions/v1');
const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

// CRITICAL: Use Firebase Admin SDK service account
setGlobalOptions({
  serviceAccount: 'firebase-adminsdk-fbsvc@financetracker-c628c.iam.gserviceaccount.com'
});

admin.initializeApp();

// --- Helpers ---

function getIconForCategory(category) {
  const categoryIcons = {
    'Dining': 'fork.knife', 'Groceries': 'cart.fill', 'Transportation': 'car.fill',
    'Shopping': 'bag.fill', 'Entertainment': 'tv.fill', 'Utilities': 'bolt.fill',
    'Health': 'heart.fill', 'Salary': 'dollarsign.circle.fill', 'Freelance': 'laptopcomputer'
  };
  return categoryIcons[category] || 'dollarsign.circle';
}

function getColorForCategory(category) {
  const categoryColors = {
    'Dining': '#FF6B6B', 'Groceries': '#4ECDC4', 'Transportation': '#45B7D1',
    'Shopping': '#FFA07A', 'Entertainment': '#98D8C8', 'Utilities': '#FFD93D',
    'Health': '#6BCF7F', 'Salary': '#4CAF50', 'Freelance': '#2196F3'
  };
  return categoryColors[category] || '#757575';
}

async function getUserInfo(uid) {
  const doc = await admin.firestore().collection('users').doc(uid).get();
  if (!doc.exists) return { name: 'Someone', fcmToken: null };
  const data = doc.data();
  return {
    name: data.name || data.displayName || 'Someone',
    username: data.username || 'user',
    fcmToken: data.fcmToken,
    avatarColor: data.avatarColor || '#808080'
  };
}

async function sendNotification(uid, title, body, data) {
  try {
    const { fcmToken } = await getUserInfo(uid);
    if (!fcmToken) return;

    const message = {
      token: fcmToken,
      notification: { title, body },
      data: data,
      apns: { payload: { aps: { sound: 'default', badge: 1 } } }
    };
    await admin.messaging().send(message);
    console.log(`Notification sent to ${uid}: ${title}`);
  } catch (error) {
    console.error(`Error sending notification to ${uid}:`, error);
  }
}

// --- HTTP Functions ---

exports.addTransaction = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { UserID, Data } = req.body;
    if (!UserID || !Data) {
      res.status(400).json({ error: 'Missing required fields' });
      return;
    }
    const { Category, Type, Amount, Notes } = Data;
    const parsedAmount = parseFloat(Amount);
    if (isNaN(parsedAmount)) {
      res.status(400).json({ error: 'Invalid Amount' });
      return;
    }

    const transactionType = Type.toLowerCase();
    const finalAmount = transactionType === 'income' ? Math.abs(parsedAmount) : -Math.abs(parsedAmount);

    const transactionData = {
      title: Category, subtitle: Category, amount: finalAmount, date: new Date(),
      icon: getIconForCategory(Category), colorHex: getColorForCategory(Category),
      note: Notes || null, userId: UserID, type: transactionType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(), source: 'shortcuts'
    };

    const docRef = await admin.firestore().collection('users').doc(UserID).collection('transactions').add(transactionData);
    res.status(200).json({ success: true, transactionId: docRef.id });
  } catch (error) {
    console.error('Error adding transaction:', error);
    res.status(500).json({ error: error.message });
  }
});

// --- Scheduled Functions ---

exports.processRecurringTransactions = functions.pubsub.schedule('1 0 * * *').onRun(async (context) => {
  const db = admin.firestore();
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  try {
    const snapshot = await db.collectionGroup('recurringTransactions').get();
    if (snapshot.empty) return null;

    const batch = db.batch();
    let count = 0;

    for (const doc of snapshot.docs) {
      const item = doc.data();
      const userRef = doc.ref.parent.parent;
      if (!userRef) continue;
      const userId = userRef.id;

      let nextDueDate;
      if (item.lastProcessedDate) {
        nextDueDate = item.lastProcessedDate.toDate();
        switch (item.frequency) {
          case "Daily": nextDueDate.setDate(nextDueDate.getDate() + 1); break;
          case "Weekly": nextDueDate.setDate(nextDueDate.getDate() + 7); break;
          case "Bi-Weekly": nextDueDate.setDate(nextDueDate.getDate() + 14); break;
          case "Yearly": nextDueDate.setFullYear(nextDueDate.getFullYear() + 1); break;
          default: nextDueDate.setMonth(nextDueDate.getMonth() + 1); break;
        }
      } else {
        nextDueDate = item.startDate.toDate();
      }

      const nextDueStart = new Date(nextDueDate);
      nextDueStart.setHours(0, 0, 0, 0);

      if (nextDueStart <= today) {
        const type = item.type || "expense";
        const finalAmount = (type === "income") ? Math.abs(item.amount) : -Math.abs(item.amount);

        const newTxRef = userRef.collection('transactions').doc();
        batch.set(newTxRef, {
          title: item.name, subtitle: item.name, amount: finalAmount,
          date: admin.firestore.Timestamp.fromDate(nextDueStart),
          icon: item.icon, colorHex: item.colorHex,
          note: `Recurring: ${item.frequency}` + (item.note ? ` - ${item.note}` : ""),
          type: type, source: 'recurring', userId: userId,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        batch.update(doc.ref, { lastProcessedDate: admin.firestore.Timestamp.fromDate(nextDueStart) });
        count++;
      }
    }

    if (count > 0) await batch.commit();
    return null;
  } catch (error) {
    console.error('Error processing recurring:', error);
    return null;
  }
});

// --- v2.1 Social Triggers ---

// 1. Friend Requests
exports.v2_onFriendRequestCreated = onDocumentCreated('friend_requests/{requestId}', async (event) => {
  const data = event.data.data();
  if (!data) return;
  const sender = await getUserInfo(data.fromUid);
  await sendNotification(data.toUid, 'New Friend Request', `${sender.name} wants to be friends!`, { type: 'friend_request', id: event.params.requestId });
});

exports.v2_onFriendRequestUpdated = onDocumentUpdated('friend_requests/{requestId}', async (event) => {
  const after = event.data.after.data();
  if (after.status === 'accepted') {
    const batch = admin.firestore().batch();
    const fromInfo = await getUserInfo(after.fromUid);
    const toInfo = await getUserInfo(after.toUid);

    // a. Bidirectional Friend Added
    const fromFriendRef = admin.firestore().collection('users').doc(after.toUid).collection('friends').doc(after.fromUid);
    batch.set(fromFriendRef, {
      id: after.fromUid, username: fromInfo.username, name: fromInfo.name,
      avatarColor: fromInfo.avatarColor, createdAt: new Date()
    });

    const toFriendRef = admin.firestore().collection('users').doc(after.fromUid).collection('friends').doc(after.toUid);
    batch.set(toFriendRef, {
      id: after.toUid, username: toInfo.username, name: toInfo.name,
      avatarColor: toInfo.avatarColor, createdAt: new Date()
    });

    // b. Unblock Group Invitations
    const invites = await admin.firestore().collection('group_invitations').where('dependencyId', '==', event.params.requestId).get();
    invites.docs.forEach(doc => batch.update(doc.ref, { status: 'pending' }));

    await batch.commit();
    await sendNotification(after.fromUid, 'Friend Request Accepted', `${toInfo.name} accepted your request!`, { type: 'friend_accepted' });
  }
});

// 2. Group Invitations
exports.v2_onGroupInvitationCreated = onDocumentCreated('group_invitations/{inviteId}', async (event) => {
  const data = event.data.data();
  if (!data || data.status === 'blocked_by_friendship') return; // Don't notify if blocked
  const sender = await getUserInfo(data.fromUid);
  await sendNotification(data.toUid, 'Group Invite', `${sender.name} invited you to join "${data.groupName}"`, { type: 'group_invite', id: event.params.inviteId });
});

exports.v2_onGroupInvitationUpdated = onDocumentUpdated('group_invitations/{inviteId}', async (event) => {
  const after = event.data.after.data();
  const headers = event.data.before.data();

  // Notify if unblocked
  if (headers.status === 'blocked_by_friendship' && after.status === 'pending') {
    const sender = await getUserInfo(after.fromUid);
    await sendNotification(after.toUid, 'Group Invite', `${sender.name} invited you to join "${after.groupName}"`, { type: 'group_invite', id: event.params.inviteId });
  }

  if (after.status === 'accepted') {
    const batch = admin.firestore().batch();

    // a. Add to Group Members
    const groupRef = admin.firestore().collection('groups').doc(after.groupId);
    batch.update(groupRef, { members: admin.firestore.FieldValue.arrayUnion(after.toUid) });

    // b. Unblock Split Requests
    const requests = await admin.firestore().collection('split_requests').where('dependencyId', '==', event.params.inviteId).get();
    requests.docs.forEach(doc => batch.update(doc.ref, { status: 'pending' }));

    await batch.commit();
  }
});

// 3. Split Requests
exports.v2_onSplitRequestCreated = onDocumentCreated('split_requests/{requestId}', async (event) => {
  const data = event.data.data();
  if (!data || data.status === 'blocked_by_group') return; // Don't notify if blocked
  const sender = await getUserInfo(data.fromUid);
  await sendNotification(data.toUid, 'Split Request', `${sender.name} requests $${data.amount.toFixed(2)} for ${data.note}`, { type: 'split_request', id: event.params.requestId });
});

exports.v2_onSplitRequestUpdated = onDocumentUpdated('split_requests/{requestId}', async (event) => {
  const after = event.data.after.data();
  const before = event.data.before.data();

  // Notify if unblocked
  if (before.status === 'blocked_by_group' && after.status === 'pending') {
    const sender = await getUserInfo(after.fromUid);
    await sendNotification(after.toUid, 'Split Request', `${sender.name} requests $${after.amount.toFixed(2)} for ${after.note}`, { type: 'split_request', id: event.params.requestId });
  }

  if (after.status === 'accepted') {
    // Update Transaction
    const transactionRef = admin.firestore().collection('users').doc(after.fromUid).collection('transactions').doc(after.transactionId);

    try {
      await admin.firestore().runTransaction(async (t) => {
        const doc = await t.get(transactionRef);
        if (!doc.exists) return;
        const txData = doc.data();

        // Find and update split
        const splits = txData.splits || [];
        // Find split by requestId (v2.1)
        const splitIndex = splits.findIndex(s => s.requestId === event.params.requestId);

        if (splitIndex !== -1) {
          splits[splitIndex].isAccepted = true;
          // Also set isPaid if we want to auto-mark (optional, spec says keep separate?)
          // Spec says: "Accepting a split request acknowledges the debt."
          // It does NOT automatically pay it.
          t.update(transactionRef, { splits: splits });
        }
      });

      const receiver = await getUserInfo(after.toUid);
      await sendNotification(after.fromUid, 'Split Accepted', `${receiver.name} accepted your request.`, { type: 'split_accepted' });

    } catch (e) {
      console.error('Error syncing split acceptance:', e);
    }
  }
});


// --- LEGACY TRIGGERS (Backward Compatibility) ---

exports.onSplitRequestCreatedLegacy = onDocumentCreated('users/{userId}/requests/{requestId}', async (event) => {
  // Existing logic for legacy path
  const request = event.data.data();
  if (!request) return;
  const sender = await getUserInfo(request.requesterId);
  await sendNotification(event.params.userId, 'Split Request', `${sender.name} wants to split $${Math.abs(request.amount).toFixed(2)}`, { type: 'split_request', id: event.params.requestId });
});

exports.onSplitRequestUpdatedLegacy = onDocumentUpdated('users/{userId}/requests/{requestId}', async (event) => {
  const after = event.data.after.data();
  const before = event.data.before.data();
  if (after.status === before.status) return;

  const target = await getUserInfo(event.params.userId); // Responder
  let title = after.status === 'accepted' ? '✅ Split Accepted' : 'Split Declined';
  await sendNotification(after.fromUserId, title, `${target.name} ${after.status} your split.`, { type: 'split_response' });
});

exports.onTransactionUpdated = onDocumentUpdated('users/{userId}/transactions/{transactionId}', async (event) => {
  const afterData = event.data.after.data();
  // ✅ CRITICAL: Skip v2.1 transactions to avoid duplicate request creation
  if (afterData.source === 'social_v2') return;

  // ... Existing Legacy Logic (Preserved but skipped for new app version) ...
  const beforeData = event.data.before.data();
  const transactionId = event.params.transactionId;
  const senderId = event.params.userId;
  const beforeSplits = beforeData.splits || [];
  const afterSplits = afterData.splits || [];

  // Removed Splits Logic
  const afterSplitIds = new Set(afterSplits.map(s => s.id));
  const removedSplits = beforeSplits.filter(s => !afterSplitIds.has(s.id));

  const senderInfo = await getUserInfo(senderId);

  for (const split of removedSplits) {
    if (split.friendId) {
      const reqId = split.requestId || transactionId;
      await deleteSplitRequestLegacy(split.friendId, reqId, senderInfo.name, split.amount);
    }
  }

  // Added/Updated Splits Logic
  for (const split of afterSplits) {
    if (!split.friendId) continue;
    const oldSplit = beforeSplits.find(s => s.id === split.id);
    if (!oldSplit || Math.abs(oldSplit.amount - split.amount) > 0.01) {
      // Upsert legacy request
      const requestData = {
        requesterId: senderId, requesterName: senderInfo.name,
        amount: split.amount, note: afterData.note || afterData.title || 'Split Bill',
        originalTransactionId: transactionId, status: 'pending',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };
      await admin.firestore().collection('users').doc(split.friendId).collection('requests').doc(transactionId).set(requestData, { merge: true });
    }
  }
});

exports.onTransactionDeleted = onDocumentDeleted('users/{userId}/transactions/{transactionId}', async (event) => {
  const data = event.data.data();
  if (!data) return;
  const splits = data.splits || [];
  if (splits.length === 0) return;
  const senderInfo = await getUserInfo(event.params.userId);

  for (const split of splits) {
    if (split.friendId && split.requestId) {
      await deleteSplitRequestLegacy(split.friendId, split.requestId, senderInfo.name, split.amount);
    }
  }
});

async function deleteSplitRequestLegacy(friendId, transactionId, senderName, amount) {
  try {
    const snapshot = await admin.firestore().collection('users').doc(friendId).collection('requests').where('originalTransactionId', '==', transactionId).get();
    if (snapshot.empty) return;
    const batch = admin.firestore().batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    await sendNotification(friendId, 'Split Removed', `${senderName} removed the split.`, { type: 'split_removed' });
  } catch (e) { console.error(e); }
}
