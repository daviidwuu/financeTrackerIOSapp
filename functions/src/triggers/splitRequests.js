const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { checkIdempotency, getUserInfo, sendNotification } = require('../helpers');

const ACTIVE_STATUSES = ['pending', 'accepted'];

function splitStatusForRequest(status) {
    return ['pending', 'accepted', 'declined', 'paid'].includes(status) ? status : 'pending';
}

function isPaidStatus(status) {
    return status === 'paid';
}

function isAcceptedStatus(status) {
    return status === 'accepted' || status === 'paid';
}

function shouldCreateIncomeForPaidRequest(data) {
    return data.status === 'paid' && data.isSettlement !== true && !data.settledByRequestId;
}

function buildSplitProjection(requestId, data, existing = {}) {
    const paid = isPaidStatus(data.status);
    const accepted = isAcceptedStatus(data.status);
    const projection = {
        ...existing,
        id: existing.id || data.toUid || requestId,
        name: data.toName || existing.name || 'Member',
        amount: data.amount,
        splitStatus: splitStatusForRequest(data.status),
        isPaid: paid,
        isAccepted: accepted,
        status: splitStatusForRequest(data.status),
        paidDate: paid ? (existing.paidDate || new Date()) : null,
        requestId
    };

    if (data.isGuest) {
        projection.isGuest = true;
        projection.guestId = data.toUid;
        delete projection.friendId;
    } else {
        projection.isGuest = false;
        projection.friendId = data.toUid;
        delete projection.guestId;
    }

    if (data.toUsername || existing.username) {
        projection.username = data.toUsername || existing.username;
    }

    return projection;
}

function findSplitIndex(splits, requestId, data) {
    return splits.findIndex(s => (
        s.requestId === requestId
        || (!s.requestId && data.isGuest && s.guestId === data.toUid)
        || (!s.requestId && !data.isGuest && s.friendId === data.toUid)
    ));
}

function groupTransactionQuery(db, groupId, originalTransactionId) {
    return db.collection('groups')
        .doc(groupId)
        .collection('transactions')
        .where('originalTransactionId', '==', originalTransactionId)
        .limit(10);
}

async function syncGroupStatusProjection(db, requestId, before, after) {
    if (!after.groupId || !after.transactionId) return;

    const snapshot = await groupTransactionQuery(db, after.groupId, after.transactionId).get();
    if (snapshot.empty) return;

    const batch = db.batch();
    snapshot.docs.forEach((doc, index) => {
        if (index === 0) {
            batch.update(doc.ref, {
                [`involvedUserStatuses.${after.toUid}`]: after.status
            });
        } else {
            console.warn(`[Split] Duplicate group transaction for ${requestId}; leaving duplicate ${doc.id} unchanged.`);
        }
    });
    await batch.commit();
}

async function syncSourceTransactionProjection(db, requestId, before, after) {
    if (!after.transactionId || !after.fromUid || !after.toUid) return;

    const transactionRef = db.collection('users')
        .doc(after.fromUid)
        .collection('transactions')
        .doc(after.transactionId);

    await db.runTransaction(async (t) => {
        const doc = await t.get(transactionRef);
        if (!doc.exists) return;

        const txData = doc.data();
        const splits = Array.isArray(txData.splits) ? [...txData.splits] : [];
        const splitIndex = findSplitIndex(splits, requestId, after);

        if (after.status === 'declined') {
            if (splitIndex !== -1) {
                t.update(transactionRef, {
                    splits: splits.filter(s => s.requestId !== requestId)
                });
                console.log(`[Split] DECLINED: Removed split projection for ${requestId}.`);
            }
            return;
        }

        const existingSplit = splitIndex === -1 ? {} : splits[splitIndex];
        const nextSplit = buildSplitProjection(requestId, after, existingSplit);

        if (isPaidStatus(after.status) && shouldCreateIncomeForPaidRequest(after)) {
            const existingIncomeId = existingSplit.incomeTransactionId;
            const incomeRef = db.collection('users')
                .doc(after.fromUid)
                .collection('transactions')
                .doc(existingIncomeId || `split_income_${requestId}`);

            const incomeData = {
                title: `Payment received from ${after.toName || 'User'}`,
                amount: after.amount,
                date: txData.date || new Date(),
                note: `Payment received from ${after.toName || 'User'}`,
                userId: after.fromUid,
                type: 'income',
                source: requestId,
                categoryId: txData.categoryId || null,
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            };

            t.set(incomeRef, incomeData, { merge: true });
            nextSplit.incomeTransactionId = incomeRef.id;
        }

        if (before && before.status === 'paid' && after.status !== 'paid') {
            const incomeId = existingSplit.incomeTransactionId;
            if (incomeId) {
                const incomeRef = db.collection('users')
                    .doc(after.fromUid)
                    .collection('transactions')
                    .doc(incomeId);
                t.delete(incomeRef);
            }
            nextSplit.incomeTransactionId = null;
        }

        if (splitIndex === -1) {
            splits.push(nextSplit);
        } else {
            splits[splitIndex] = nextSplit;
        }

        t.update(transactionRef, { splits });
        console.log(`[Split] Synced status '${after.status}' to source transaction for ${requestId}.`);
    });
}

async function syncSplitSideEffects(requestId, before, after) {
    const db = admin.firestore();
    const created = !before;
    const statusChanged = created || before.status !== after.status;

    if (!statusChanged && before.amount === after.amount && before.toUid === after.toUid) {
        return;
    }

    await syncSourceTransactionProjection(db, requestId, before, after);
    if (statusChanged) {
        await syncGroupStatusProjection(db, requestId, before, after);
    }
}

// 1. Split Request Created
exports.v2_onSplitRequestCreated = onDocumentCreated('split_requests/{requestId}', async (event) => {
    if (await checkIdempotency(event.id)) return;
    const data = event.data.data();
    if (!data || data.status === 'blocked_by_group') return; // Don't notify if blocked
    await syncSplitSideEffects(event.params.requestId, null, data);
    if (data.isGuest) return; // Guests don't have accounts — skip notifications
    const sender = await getUserInfo(data.fromUid);

    if (data.status === 'paid') {
        // FIX #1: Do NOT create income here. Income creation is handled exclusively by
        // v2_onSplitRequestUpdated when status transitions to 'paid'. Creating it here as well
        // causes duplicate income transactions for settlements (which are created with status='paid').
        await sendNotification(data.toUid, 'Payment Received', `${sender.name} paid you $${data.amount.toFixed(2)}`, { type: 'split_paid', id: event.params.requestId });
    } else {
        await sendNotification(data.toUid, 'Split Request', `${sender.name} requests $${data.amount.toFixed(2)} for ${data.note}`, { type: 'split_request', id: event.params.requestId });
    }
});

// 2. Split Request Updated (status changes, nudges, payment sync)
exports.v2_onSplitRequestUpdated = onDocumentUpdated('split_requests/{requestId}', async (event) => {
    if (await checkIdempotency(event.id)) return;
    const after = event.data.after.data();
    const before = event.data.before.data();
    const note = after.note || 'Expense';

    // --- Unblock Notification ---
    if (before.status === 'blocked_by_group' && after.status === 'pending') {
        const sender = await getUserInfo(after.fromUid);
        await sendNotification(after.toUid, 'Split Request', `${sender.name} requests $${after.amount.toFixed(2)} for ${note}`, { type: 'split_request', id: event.params.requestId });
        return;
    }

    // --- S4: Resend Notification (declined → pending) ---
    if (before.status === 'declined' && after.status === 'pending') {
        const sender = await getUserInfo(after.fromUid);
        await sendNotification(after.toUid, 'Split Request (Resent)', `${sender.name} resent a $${after.amount.toFixed(2)} request for ${note}`, { type: 'split_request', id: event.params.requestId });
        return;
    }

    // --- Nudge Notification ---
    if (after.lastNudgedAt && (!before.lastNudgedAt || after.lastNudgedAt.toMillis() > before.lastNudgedAt.toMillis())) {
        const sender = await getUserInfo(after.fromUid);
        await sendNotification(after.toUid, 'Reminder', `${sender.name} nudged you about ${note} ($${after.amount.toFixed(2)})`, { type: 'split_nudge', id: event.params.requestId });
        return;
    }

    // --- Status Change Logic ---
    if (after.status !== before.status) {
        try {
            await syncSplitSideEffects(event.params.requestId, before, after);

            // --- Send Notifications Based on Status Change ---
            // Skip notifications for guest splits — guests don't have user accounts
            if (!after.isGuest) {
                if (after.status === 'paid' && before.status !== 'paid') {
                    console.log(`[Split] PAID notification: processing payment status change.`);
                    if (after.lastUpdatedBy === after.fromUid) {
                        // Creditor marked it → Notify Debtor
                        const creditor = await getUserInfo(after.fromUid);
                        await sendNotification(after.toUid, 'Payment Confirmed', `${creditor.name} marked your split as paid.`, { type: 'split_paid', id: event.params.requestId });
                    } else {
                        // Debtor marked it → Notify Creditor
                        const debtor = await getUserInfo(after.toUid);
                        await sendNotification(after.fromUid, 'Payment Received', `${debtor.name} marked the split as paid.`, { type: 'split_paid', id: event.params.requestId });
                    }
                } else if (after.status === 'declined' && before.status !== 'declined') {
                    const receiver = await getUserInfo(after.toUid);
                    await sendNotification(after.fromUid, 'Request Declined', `${receiver.name} declined to pay.`, { type: 'split_declined' });
                } else if (after.status === 'accepted' && before.status !== 'accepted') {
                    const receiver = await getUserInfo(after.toUid);
                    await sendNotification(after.fromUid, 'Split Accepted', `${receiver.name} accepted your request.`, { type: 'split_accepted' });
                } else if (before.status === 'paid' && after.status !== 'paid') {
                    // S3: Notify about payment revert
                    console.log(`[Split] UNPAID: processing payment revert.`);
                    if (after.lastUpdatedBy === after.fromUid) {
                        const creditor = await getUserInfo(after.fromUid);
                        await sendNotification(after.toUid, 'Payment Reverted', `${creditor.name} unmarked the payment for ${note}.`, { type: 'split_unpaid', id: event.params.requestId });
                    } else {
                        const debtor = await getUserInfo(after.toUid);
                        await sendNotification(after.fromUid, 'Payment Reverted', `${debtor.name} unmarked the payment for ${note}.`, { type: 'split_unpaid', id: event.params.requestId });
                    }
                }
            }

        } catch (e) {
            console.error('[Split] Error syncing split status:', e);
        }
    }
});

// 3. Split Request Deleted (Cancel Notification + Paid Cleanup)
exports.v2_onSplitRequestDeleted = onDocumentDeleted('split_requests/{requestId}', async (event) => {
    if (await checkIdempotency(event.id)) return;
    const data = event.data.data();
    if (!data) return;
    console.log(`[Split] Request deleted. Notifying receiver.`);
    if (!data.isGuest) {
        const sender = await getUserInfo(data.fromUid);
        await sendNotification(data.toUid, 'Split Cancelled', `${sender.name} cancelled the $${data.amount.toFixed(2)} request for ${data.note || 'Expense'}.`, { type: 'split_cancelled' });
    }

    // --- Gap #8 Fix: Clean up linked income/expense transactions if split was paid ---
    if (data.status === 'paid') {
        try {
            const transactionRef = admin.firestore().collection('users').doc(data.fromUid).collection('transactions').doc(data.transactionId);
            const txDoc = await transactionRef.get();
            if (txDoc.exists) {
                const txData = txDoc.data();
                const splits = txData.splits || [];
                const split = splits.find(s => s.requestId === event.params.requestId);

                if (split) {
                    const batch = admin.firestore().batch();

                    // Delete creditor income transaction
                    if (split.incomeTransactionId) {
                        const incomeRef = admin.firestore().collection('users').doc(data.fromUid).collection('transactions').doc(split.incomeTransactionId);
                        batch.delete(incomeRef);
                        console.log(`[Split] Cleaning up creditor income transaction.`);
                    }



                    // Remove the split entry from the source transaction
                    const updatedSplits = splits.filter(s => s.requestId !== event.params.requestId);
                    batch.update(transactionRef, { splits: updatedSplits });

                    await batch.commit();
                    console.log(`[Split] Paid split cleanup complete.`);
                }
            }
        } catch (e) {
            console.error('[Split] Error cleaning up paid split on delete:', e);
        }
    }
});
