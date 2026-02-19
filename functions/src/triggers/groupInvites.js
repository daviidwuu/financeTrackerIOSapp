const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { getUserInfo, sendNotification } = require('../helpers');

// 1. Group Invitation Created
exports.v2_onGroupInvitationCreated = onDocumentCreated('group_invitations/{inviteId}', async (event) => {
    const data = event.data.data();
    if (!data || data.status === 'blocked_by_friendship') return; // Don't notify if blocked
    const sender = await getUserInfo(data.fromUid);
    await sendNotification(data.toUid, 'Group Invite', `${sender.name} invited you to join "${data.groupName}"`, { type: 'group_invite', id: event.params.inviteId });
});

// 2. Group Invitation Updated (accepted / declined / unblocked)
exports.v2_onGroupInvitationUpdated = onDocumentUpdated('group_invitations/{inviteId}', async (event) => {
    const after = event.data.after.data();
    const before = event.data.before.data();
    if (after.status === before.status) return; // No status change
    console.log(`[GroupInvite] ${event.params.inviteId} status: ${before.status} → ${after.status}`);

    // Notify if unblocked
    if (before.status === 'blocked_by_friendship' && after.status === 'pending') {
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

        // I1: Notify inviter that their invite was accepted
        const joiner = await getUserInfo(after.toUid);
        await sendNotification(after.fromUid, 'Invite Accepted', `${joiner.name} joined "${after.groupName || 'the group'}".`, { type: 'group_invite_accepted', id: event.params.inviteId });
    } else if (after.status === 'declined') {
        // I2: Notify inviter that their invite was declined
        const decliner = await getUserInfo(after.toUid);
        await sendNotification(after.fromUid, 'Invite Declined', `${decliner.name} declined to join "${after.groupName || 'the group'}".`, { type: 'group_invite_declined', id: event.params.inviteId });
    }
});
