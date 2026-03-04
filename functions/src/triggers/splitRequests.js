const { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { checkIdempotency, getUserInfo, sendNotification } = require('../helpers');

// 1. Split Request Created
exports.v2_onSplitRequestCreated = onDocumentCreated('split_requests/{requestId}', async (event) => {
    if (await checkIdempotency(event.id)) return;
    const data = event.data.data();
    if (!data || data.status === 'blocked_by_group') return; // Don't notify if blocked
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
        const transactionRef = admin.firestore().collection('users').doc(after.fromUid).collection('transactions').doc(after.transactionId);

        try {
            // FIX #2: Increase max retry attempts to handle contention with client batch writes
            await admin.firestore().runTransaction(async (t) => {
                const doc = await t.get(transactionRef);
                if (!doc.exists) return;
                const txData = doc.data();

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
                    if (after.status === 'paid') {
                        if (!splits[splitIndex].isPaid) {
                            splits[splitIndex].isPaid = true;
                            splits[splitIndex].paidDate = new Date();
                            needsUpdate = true;
                        }

                        // Idempotency check — only create transactions if not already present
                        if (!splits[splitIndex].incomeTransactionId) {
                            // Create "Payment Received" income transaction for the Creditor (fromUid)
                            const incomeRef = admin.firestore().collection('users').doc(after.fromUid).collection('transactions').doc();
                            const incomeData = {
                                title: `Payment received from ${after.toName || 'User'}`,
                                amount: after.amount,
                                date: new Date(),
                                note: `Payment received from ${after.toName || 'User'}`,
                                userId: after.fromUid,
                                type: 'income',
                                source: event.params.requestId,
                                categoryId: txData.categoryId || null,
                                createdAt: admin.firestore.FieldValue.serverTimestamp()
                            };

                            t.set(incomeRef, incomeData);
                            splits[splitIndex].incomeTransactionId = incomeRef.id;
                            needsUpdate = true;
                        }


                    }

                    // Sync Unpaid Status (revert paid → pending/accepted)
                    if (before.status === 'paid' && after.status !== 'paid') {
                        splits[splitIndex].isPaid = false;
                        splits[splitIndex].paidDate = null;
                        needsUpdate = true;

                        // Delete linked creditor income transaction
                        if (splits[splitIndex].incomeTransactionId) {
                            const incomeRef = admin.firestore().collection('users').doc(after.fromUid).collection('transactions').doc(splits[splitIndex].incomeTransactionId);
                            t.delete(incomeRef);
                            splits[splitIndex].incomeTransactionId = null;
                        }


                    }

                    // Sync Accepted Status
                    if (after.status === 'accepted' && !splits[splitIndex].isAccepted) {
                        splits[splitIndex].isAccepted = true;
                        needsUpdate = true;
                    }

                    // FIX 3.3: (Removed) We no longer auto-adjust creditor's expense when split is declined.
                    // The original transaction amount remains unchanged.
                    if (after.status === 'declined' && before.status !== 'declined') {
                        t.update(transactionRef, {
                            splits: splits.filter(s => s.requestId !== event.params.requestId)
                        });
                        console.log(`[Split] DECLINED: Removed split from transaction without changing original amount.`);
                        needsUpdate = false; // Already updated above
                    }

                    if (needsUpdate) {
                        t.update(transactionRef, { splits: splits });
                        console.log(`[Split] Synced status '${after.status}' to transaction.`);
                    }
                }
            });

            // --- Send Notifications Based on Status Change ---
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
    const sender = await getUserInfo(data.fromUid);
    await sendNotification(data.toUid, 'Split Cancelled', `${sender.name} cancelled the $${data.amount.toFixed(2)} request for ${data.note || 'Expense'}.`, { type: 'split_cancelled' });

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
