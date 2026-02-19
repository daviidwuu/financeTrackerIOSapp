const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { getUserInfo, sendNotification } = require('../helpers');

// 1. Friend Request Created
exports.v2_onFriendRequestCreated = onDocumentCreated('friend_requests/{requestId}', async (event) => {
    const data = event.data.data();
    if (!data) return;
    const sender = await getUserInfo(data.fromUid);
    await sendNotification(data.toUid, 'New Friend Request', `${sender.name} wants to be friends!`, { type: 'friend_request', id: event.params.requestId });
});

// 2. Friend Request Updated (accepted / declined)
exports.v2_onFriendRequestUpdated = onDocumentUpdated('friend_requests/{requestId}', async (event) => {
    const after = event.data.after.data();
    const before = event.data.before.data();
    if (after.status === before.status) return; // No status change
    console.log(`[Friend] Request ${event.params.requestId} status: ${before.status} → ${after.status}`);

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
    } else if (after.status === 'declined') {
        // F1: Notify sender that their friend request was declined
        const receiver = await getUserInfo(after.toUid);
        await sendNotification(after.fromUid, 'Friend Request Declined', `${receiver.name} declined your friend request.`, { type: 'friend_declined' });
    }
});

// 3. Friend Deletion (Bidirectional Cleanup + Split Cancellation)
exports.v2_onFriendDeleted = onDocumentDeleted('users/{userId}/friends/{friendId}', async (event) => {
    const userId = event.params.userId;
    const friendId = event.params.friendId;

    console.log(`Friendship deleted: ${userId} removed ${friendId}. Cleaning up reverse link and splits.`);

    const batch = admin.firestore().batch();

    try {
        // 1. Delete the reverse relationship: users/{friendId}/friends/{userId}
        const reverseRef = admin.firestore().collection('users').doc(friendId).collection('friends').doc(userId);
        batch.delete(reverseRef);

        // 2. Gap #6 Fix: Cancel all active split requests between the two users
        const activeStatuses = ['pending', 'accepted'];

        // Direction 1: userId → friendId
        const q1 = await admin.firestore().collection('split_requests')
            .where('fromUid', '==', userId)
            .where('toUid', '==', friendId)
            .where('status', 'in', activeStatuses)
            .get();

        // Direction 2: friendId → userId
        const q2 = await admin.firestore().collection('split_requests')
            .where('fromUid', '==', friendId)
            .where('toUid', '==', userId)
            .where('status', 'in', activeStatuses)
            .get();

        const allDocs = [...q1.docs, ...q2.docs];
        console.log(`[Friend] Found ${allDocs.length} active splits to cancel between ${userId} and ${friendId}`);

        for (const doc of allDocs) {
            const data = doc.data();

            // FIX 2.3: Clean up linked income/expense transactions if split was paid
            if (data.status === 'paid') {
                try {
                    const txRef = admin.firestore().collection('users').doc(data.fromUid)
                        .collection('transactions').doc(data.transactionId);
                    const txDoc = await txRef.get();
                    if (txDoc.exists) {
                        const splits = txDoc.data().splits || [];
                        const split = splits.find(s => s.requestId === doc.id);
                        if (split) {
                            if (split.incomeTransactionId) {
                                batch.delete(admin.firestore().collection('users').doc(data.fromUid)
                                    .collection('transactions').doc(split.incomeTransactionId));
                                console.log(`[Friend] Cleaning up creditor income tx: ${split.incomeTransactionId}`);
                            }
                            if (split.debtorTransactionId) {
                                batch.delete(admin.firestore().collection('users').doc(data.toUid)
                                    .collection('transactions').doc(split.debtorTransactionId));
                                console.log(`[Friend] Cleaning up debtor expense tx: ${split.debtorTransactionId}`);
                            }
                        }
                    }
                } catch (cleanupErr) {
                    console.warn(`[Friend] Error cleaning up paid split ${doc.id}:`, cleanupErr);
                    // Continue with cancellation even if cleanup fails
                }
            }

            batch.update(doc.ref, { status: 'cancelled', cancelledReason: 'friendship_removed' });
        }

        await batch.commit();
    } catch (error) {
        console.error("Error in friend deletion cleanup:", error);
    }
});
