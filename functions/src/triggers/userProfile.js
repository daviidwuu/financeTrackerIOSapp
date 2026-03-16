const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

// User Profile Update (Fan-Out Consistency)
exports.v2_onUserUpdated = onDocumentUpdated('users/{userId}', async (event) => {
    const after = event.data.after.data();
    const before = event.data.before.data();
    const userId = event.params.userId;

    // Check if critical identity fields changed
    const nameChanged = after.name !== before.name;
    const usernameChanged = after.username !== before.username;
    const avatarChanged = after.avatarColor !== before.avatarColor;
    const badgeTypeChanged = after.badgeType !== before.badgeType;

    if (!nameChanged && !usernameChanged && !avatarChanged && !badgeTypeChanged) return;

    console.log(`User ${userId} updated profile. Fanning out changes...`);
    const db = admin.firestore();

    // A. Update Friends (Bidirectional)
    const friendsSnapshot = await db.collection('users').doc(userId).collection('friends').get();
    const friendUpdatePromises = friendsSnapshot.docs.map(async (doc) => {
        const friendId = doc.id;
        const friendRef = db.collection('users').doc(friendId).collection('friends').doc(userId);
        const friendUpdate = {
            name: after.name,
            username: after.username,
            avatarColor: after.avatarColor,
        };
        if (after.badgeType !== undefined) friendUpdate.badgeType = after.badgeType;
        if (after.isPremium !== undefined) friendUpdate.isPremium = after.isPremium;
        return friendRef.update(friendUpdate).catch(e => console.warn(`Failed to update friend link for ${friendId}`, e));
    });

    // B. Update Groups (Member Names)
    const groupsSnapshot = await db.collection('groups').where('members', 'array-contains', userId).get();
    const groupUpdatePromises = groupsSnapshot.docs.map(async (doc) => {
        const groupRef = doc.ref;
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

    // D. Gap #3 Fix: Update Group Transaction Feed (payerName)
    if (nameChanged) {
        const groupTxPromises = [];
        for (const groupDoc of groupsSnapshot.docs) {
            const groupTxSnapshot = await db.collection('groups').doc(groupDoc.id).collection('transactions')
                .where('payerId', '==', userId)
                .get();

            for (const txDoc of groupTxSnapshot.docs) {
                groupTxPromises.push(
                    txDoc.ref.update({ payerName: after.name })
                        .catch(e => console.warn(`Failed to update group tx ${txDoc.id} payerName`, e))
                );
            }
        }
        if (groupTxPromises.length > 0) {
            await Promise.all(groupTxPromises);
            console.log(`Updated ${groupTxPromises.length} group transaction(s) with new name`);
        }
    }

    console.log(`Profile update complete for ${userId}`);
});
