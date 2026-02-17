const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { checkIdempotency, getUserInfo, sendNotification } = require('../helpers');

// 1. Friend Requests
exports.v2_onFriendRequestCreated = onDocumentCreated('friend_requests/{requestId}', async (event) => {
  const data = event.data.data();
  if (!data) return;
  const sender = await getUserInfo(data.fromUid);
  await sendNotification(data.toUid, 'New Friend Request', `${sender.name} wants to be friends!`, { type: 'friend_request', id: event.params.requestId });
});

exports.v2_onFriendRequestUpdated = onDocumentUpdated('friend_requests/{requestId}', async (event) => {
  const after = event.data.after.data();
  console.log(`Friend Request ${event.params.requestId} updated. Status: ${after.status}`);
  
  if (after.status === 'accepted') {
    const batch = admin.firestore().batch();
    const fromInfo = await getUserInfo(after.fromUid);
    const toInfo = await getUserInfo(after.toUid);

    // a. Bidirectional Friend Added
    const fromFriendRef = admin.firestore().collection('users').doc(after.toUid).collection('friends').doc(after.fromUid);
    batch.set(fromFriendRef, {
      id: after.fromUid, username: fromInfo.username, name: fromInfo.name,
      avatarColor: fromInfo.avatarColor, addedAt: new Date()
    });

    const toFriendRef = admin.firestore().collection('users').doc(after.fromUid).collection('friends').doc(after.toUid);
    batch.set(toFriendRef, {
      id: after.toUid, username: toInfo.username, name: toInfo.name,
      avatarColor: toInfo.avatarColor, addedAt: new Date()
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
  if (await checkIdempotency(event.id)) return;
  const data = event.data.data();
  if (!data || data.status === 'blocked_by_group') return; // Don't notify if blocked
  const sender = await getUserInfo(data.fromUid);

  if (data.status === 'paid') {
    await sendNotification(data.toUid, 'Payment Received', `${sender.name} paid you $${data.amount.toFixed(2)}`, { type: 'split_paid', id: event.params.requestId });
    
    // ✅ NEW: Create "Payment Received" transaction for the Creditor (Receiver of this Settlement Request)
    // For a Settlement Request, 'fromUid' is Payer, 'toUid' is Creditor (Receiver).
    // Wait, in `settleUp`, fromUid = Payer, toUid = Receiver.
    // So we need to create Income for `toUid` (Receiver).
    
    // In `v2_onSplitRequestUpdated`, we created Income for `fromUid` because that was a request SENT by Creditor.
    // Here, this is a Settlement SENT by Payer.
    // So the Income goes to `toUid`.
    
    const incomeRef = admin.firestore().collection('users').doc(data.toUid).collection('transactions').doc();
    const incomeData = {
      title: data.note || "Payment Received", 
      subtitle: `From ${sender.name}`, 
      amount: data.amount, // Positive for Income
      date: new Date(),
      icon: 'arrow.turn.down.left', 
      colorHex: '#34C759', // Green
      note: `Settlement via App`, 
      userId: data.toUid, 
      type: 'income',
      source: 'settlement',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await incomeRef.set(incomeData);
    
  } else {
    await sendNotification(data.toUid, 'Split Request', `${sender.name} requests $${data.amount.toFixed(2)} for ${data.note}`, { type: 'split_request', id: event.params.requestId });
  }
});

exports.v2_onSplitRequestUpdated = onDocumentUpdated('split_requests/{requestId}', async (event) => {
  if (await checkIdempotency(event.id)) return;
  const after = event.data.after.data();
  const before = event.data.before.data();

  // Notify if unblocked
  if (before.status === 'blocked_by_group' && after.status === 'pending') {
    const sender = await getUserInfo(after.fromUid);
    await sendNotification(after.toUid, 'Split Request', `${sender.name} requests $${after.amount.toFixed(2)} for ${after.note}`, { type: 'split_request', id: event.params.requestId });
  }

  // ✅ NEW: Nudge Notification
  // Check if lastNudgedAt changed and is newer than before
  if (after.lastNudgedAt && (!before.lastNudgedAt || after.lastNudgedAt.toMillis() > before.lastNudgedAt.toMillis())) {
     const sender = await getUserInfo(after.fromUid);
     const note = after.note || "Expense";
     await sendNotification(after.toUid, 'Reminder', `${sender.name} nudged you about "${note}" ($${after.amount.toFixed(2)})`, { type: 'split_nudge', id: event.params.requestId });
     return; // Exit to avoid duplicate status notifications
  }

  // ✅ NEW SYNC LOGIC: Status Changed (Paid or Declined)
  if (after.status !== before.status) {
    const transactionRef = admin.firestore().collection('users').doc(after.fromUid).collection('transactions').doc(after.transactionId);

    try {
      await admin.firestore().runTransaction(async (t) => {
        const doc = await t.get(transactionRef);
        if (!doc.exists) return;
        const txData = doc.data();

        // Find and update split
        const splits = txData.splits || [];
        const splitIndex = splits.findIndex(s => s.requestId === event.params.requestId);

        if (splitIndex !== -1) {
          let needsUpdate = false;

          // Sync Status Field
          if (splits[splitIndex].status !== after.status) {
            splits[splitIndex].status = after.status;
            needsUpdate = true;
          }

          // Sync Paid Status
          if (after.status === 'paid' && !splits[splitIndex].isPaid) {
            splits[splitIndex].isPaid = true;
            splits[splitIndex].paidDate = new Date();
            needsUpdate = true;

            // ✅ NEW: Create "Payment Received" transaction for the Creditor (Sender of Request)
            // This ensures their budget reflects the reimbursement.
            // We do this inside the transaction to be safe, or separate batch?
            // Transaction is better but we are modifying 't'.
            
            const incomeRef = admin.firestore().collection('users').doc(after.fromUid).collection('transactions').doc();
            const incomeData = {
              title: after.note || "Payment Received", 
              subtitle: `From ${after.toName || "Friend"}`, 
              amount: after.amount, // Positive for Income
              date: new Date(),
              icon: 'arrow.turn.down.left', 
              colorHex: '#34C759', // Green
              note: `Split Payment via App`, 
              userId: after.fromUid, 
              type: 'income',
              source: 'split_payment',
              createdAt: admin.firestore.FieldValue.serverTimestamp()
            };
            
            t.set(incomeRef, incomeData);
            
            // Link this income transaction to the split so we can delete it later if needed
            splits[splitIndex].incomeTransactionId = incomeRef.id;
          }

          // Sync Accepted Status (Legacy & New)
          if (after.status === 'accepted' && !splits[splitIndex].isAccepted) {
            splits[splitIndex].isAccepted = true;
            needsUpdate = true;
          }

          if (needsUpdate) {
            t.update(transactionRef, { splits: splits });
            console.log(`Synced split status '${after.status}' to transaction ${after.transactionId}`);
          }
        }
      });

      // Notify Sender
      if (after.status === 'paid' && before.status !== 'paid') {
        const debtor = await getUserInfo(after.toUid);
        
        if (after.lastUpdatedBy === after.fromUid) {
             // Creditor marked it -> Notify Debtor
             const creditor = await getUserInfo(after.fromUid);
             await sendNotification(after.toUid, 'Payment Confirmed', `${creditor.name} marked your split as paid.`, { type: 'split_paid', id: event.params.requestId });
        } else {
             // Debtor marked it -> Notify Creditor
             await sendNotification(after.fromUid, 'Payment Received', `${debtor.name} marked the split as paid.`, { type: 'split_paid', id: event.params.requestId });
        }
      } else if (after.status === 'declined' && before.status !== 'declined') {
        const receiver = await getUserInfo(after.toUid);
        await sendNotification(after.fromUid, 'Request Declined', `${receiver.name} declined to pay.`, { type: 'split_declined' });
      } else if (after.status === 'accepted' && before.status !== 'accepted') {
        const receiver = await getUserInfo(after.toUid);
        await sendNotification(after.fromUid, 'Split Accepted', `${receiver.name} accepted your request.`, { type: 'split_accepted' });
      }

    } catch (e) {
      console.error('Error syncing split status:', e);
    }
  }
});



// 4. Friend Deletion (Bidirectional Cleanup)
exports.v2_onFriendDeleted = onDocumentDeleted('users/{userId}/friends/{friendId}', async (event) => {
  const userId = event.params.userId;
  const friendId = event.params.friendId;
  
  console.log(`Friendship deleted: ${userId} removed ${friendId}. Cleaning up reverse link.`);
  
  try {
    // Delete the reverse relationship: users/{friendId}/friends/{userId}
    const reverseRef = admin.firestore().collection('users').doc(friendId).collection('friends').doc(userId);
    await reverseRef.delete();
  } catch (error) {
    console.error("Error removing reverse friend link:", error);
  }
});

// 5. User Profile Update (Fan-Out Consistency)
exports.v2_onUserUpdated = onDocumentUpdated('users/{userId}', async (event) => {
  const after = event.data.after.data();
  const before = event.data.before.data();
  const userId = event.params.userId;

  // Check if critical identity fields changed
  const nameChanged = after.name !== before.name;
  const usernameChanged = after.username !== before.username;
  const avatarChanged = after.avatarColor !== before.avatarColor;

  if (!nameChanged && !usernameChanged && !avatarChanged) return;

  console.log(`User ${userId} updated profile. Fanning out changes...`);
  const db = admin.firestore();

  // A. Update Friends (Bidirectional)
  // We need to find all users who have this user as a friend.
  // Query: collectionGroup('friends').where('id', '==', userId)
  // This might be expensive. Better: We know who OUR friends are.
  // If A is friends with B, B is friends with A.
  // So we iterate over `users/{userId}/friends` to find B, C, D...
  // Then update `users/{B}/friends/{A}`.
  
  const friendsSnapshot = await db.collection('users').doc(userId).collection('friends').get();
  const friendUpdatePromises = friendsSnapshot.docs.map(async (doc) => {
    const friendId = doc.id;
    const friendRef = db.collection('users').doc(friendId).collection('friends').doc(userId);
    // Update the denormalized data
    return friendRef.update({
      name: after.name,
      username: after.username,
      avatarColor: after.avatarColor
    }).catch(e => console.warn(`Failed to update friend link for ${friendId}`, e));
  });

  // B. Update Groups (Member Names)
  // Find groups where this user is a member.
  const groupsSnapshot = await db.collection('groups').where('members', 'array-contains', userId).get();
  const groupUpdatePromises = groupsSnapshot.docs.map(async (doc) => {
    const groupRef = doc.ref;
    // memberNames is a Map: { uid: name }
    // We use dot notation to update a specific key in the map
    const updateData = {};
    updateData[`memberNames.${userId}`] = after.name;
    return groupRef.update(updateData).catch(e => console.warn(`Failed to update group ${doc.id}`, e));
  });

  // C. Update Active Split Requests (Outgoing & Incoming)
  // 1. Outgoing (fromUid == userId)
  const outgoingSnapshot = await db.collection('split_requests')
    .where('fromUid', '==', userId)
    .where('status', 'in', ['pending', 'accepted']) // Only active
    .get();
    
  const outgoingPromises = outgoingSnapshot.docs.map(doc => {
    return doc.ref.update({ fromName: after.name });
  });

  // 2. Incoming (toUid == userId)
  const incomingSnapshot = await db.collection('split_requests')
    .where('toUid', '==', userId)
    .where('status', 'in', ['pending', 'accepted']) // Only active
    .get();
    
  const incomingPromises = incomingSnapshot.docs.map(doc => {
    return doc.ref.update({ toName: after.name });
  });

  // Execute all
  await Promise.all([
    ...friendUpdatePromises,
    ...groupUpdatePromises,
    ...outgoingPromises,
    ...incomingPromises
  ]);
  
  console.log(`Profile update complete for ${userId}`);
});

// 6. Group Member Added (Direct Add Notification)
exports.v2_onGroupMemberAdded = onDocumentUpdated('groups/{groupId}', async (event) => {
  const after = event.data.after.data();
  const before = event.data.before.data();
  const groupId = event.params.groupId;

  // Find new members
  const oldMembers = new Set(before.members || []);
  const newMembers = (after.members || []).filter(uid => !oldMembers.has(uid));

  if (newMembers.length === 0) return;

  const groupName = after.name || "Group";
  
  // Try to find who added them by checking 'updatedBy' if you add that field in the client update,
  // otherwise default to generic message.
  // Ideally, update the client to set 'updatedBy' or similar.
  // For now, we'll check if we can infer or just use generic.
  
  console.log(`New members added to group ${groupId}: ${newMembers.join(', ')}`);

  const promises = newMembers.map(async (uid) => {
    // We don't have the "adder" ID easily available unless we store it in the group doc on update.
    // However, if we look at who triggered the write... functions v2 doesn't expose auth context easily in triggers yet.
    // We'll use a generic "You have been added" or try to find a recent log? No, keep it simple.
    
    // Improvement: Client sets 'lastUpdatedBy' field on group update.
    // If available, fetch that user.
    let adderName = "A friend";
    if (after.lastUpdatedBy) {
         const adder = await getUserInfo(after.lastUpdatedBy);
         adderName = adder.name;
    } else if (after.createdBy && oldMembers.size === 0) {
         // New group creation
         const creator = await getUserInfo(after.createdBy);
         adderName = creator.name;
    }

    await sendNotification(
      uid, 
      'New Group', 
      `You have been added into ${groupName} by ${adderName}`, 
      { type: 'group_add', id: groupId }
    );
  });

  await Promise.all(promises);
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
