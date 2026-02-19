const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { getUserInfo, sendNotification } = require('../helpers');

// --- Gap #7 Fix: Merged v2_onGroupMemberAdded + v2_onGroupUpdated into a single trigger ---
exports.v2_onGroupUpdated = onDocumentUpdated('groups/{groupId}', async (event) => {
    const after = event.data.after.data();
    const before = event.data.before.data();
    const groupId = event.params.groupId;

    // --- Branch 1: New Members Added ---
    const oldMembers = new Set(before.members || []);
    const newMembers = (after.members || []).filter(uid => !oldMembers.has(uid));

    if (newMembers.length > 0) {
        const groupName = after.name || "Group";
        console.log(`New members added to group ${groupId}: ${newMembers.join(', ')}`);

        const promises = newMembers.map(async (uid) => {
            let adderName = "A friend";
            if (after.lastUpdatedBy) {
                const adder = await getUserInfo(after.lastUpdatedBy);
                adderName = adder.name;
            } else if (after.createdBy && oldMembers.size === 0) {
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
    }

    // --- Branch 2: Deletion Request ---
    if (before.deletionStatus !== 'requested' && after.deletionStatus === 'requested') {
        console.log(`Group ${groupId} deletion requested. Notifying members...`);

        const members = after.members || [];
        const groupName = after.name || "Group";

        const requesterId = after.lastUpdatedBy;
        let requesterName = "A member";

        if (requesterId) {
            try {
                const user = await getUserInfo(requesterId);
                requesterName = user.name;
            } catch (e) {
                console.warn("Could not fetch requester info", e);
            }
        }

        const notifyPromises = members.map(async (uid) => {
            if (uid === requesterId) return;
            await sendNotification(
                uid,
                'Group Deletion Requested',
                `${requesterName} has requested to delete "${groupName}". Action required.`,
                { type: 'group_deletion', id: groupId }
            );
        });

        await Promise.all(notifyPromises);
    }

    // --- Branch 3: Member Removed (Leave Group) ---
    const removedMembers = (before.members || []).filter(uid => !(after.members || []).includes(uid));
    if (removedMembers.length > 0) {
        const groupName = after.name || "Group";
        console.log(`Members removed from group ${groupId}: ${removedMembers.join(', ')}`);

        // Notify remaining members
        const remainingMembers = after.members || [];
        for (const removedUid of removedMembers) {
            let memberName = "A member";
            try {
                const userInfo = await getUserInfo(removedUid);
                memberName = userInfo.name;
            } catch (e) { /* fallback name */ }

            const notifyPromises = remainingMembers.map(async (uid) => {
                await sendNotification(
                    uid,
                    'Member Left',
                    `${memberName} left "${groupName}".`,
                    { type: 'group_member_left', id: groupId }
                );
            });

            await Promise.all(notifyPromises);
        }
    }
});

// FIX 2.5: Clean up group subcollections when group is deleted
// Firestore does NOT cascade-delete subcollections automatically.
const { onDocumentDeleted } = require('firebase-functions/v2/firestore');

exports.v2_onGroupDeleted = onDocumentDeleted('groups/{groupId}', async (event) => {
    const groupId = event.params.groupId;
    console.log(`Group ${groupId} deleted. Cleaning up subcollections...`);

    const db = admin.firestore();
    const subcollections = ['transactions', 'archived_transactions'];
    let totalDeleted = 0;

    for (const subcol of subcollections) {
        const snapshot = await db.collection('groups').doc(groupId).collection(subcol).get();
        if (snapshot.empty) continue;

        // Batch delete in chunks of 500 (Firestore limit)
        const chunks = [];
        for (let i = 0; i < snapshot.docs.length; i += 500) {
            chunks.push(snapshot.docs.slice(i, i + 500));
        }

        for (const chunk of chunks) {
            const batch = db.batch();
            chunk.forEach(doc => batch.delete(doc.ref));
            await batch.commit();
            totalDeleted += chunk.length;
        }
    }

    console.log(`Cleaned up ${totalDeleted} orphaned docs for deleted group ${groupId}`);
});
