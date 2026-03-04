const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

// FIX #5: Process recurring transactions with sub-batching (max 250 items per batch = 500 ops)
// and catch-up logic for missed periods.
const MAX_ITEMS_PER_BATCH = 250;

exports.processRecurringTransactions = functions.pubsub.schedule('1 0 * * *').timeZone('Asia/Singapore').onRun(async (context) => {
  const db = admin.firestore();
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  try {
    const snapshot = await db.collectionGroup('recurringTransactions').get();
    if (snapshot.empty) return null;

    // Collect all operations first
    const operations = [];

    for (const doc of snapshot.docs) {
      const item = doc.data();
      const userRef = doc.ref.parent.parent;
      if (!userRef) continue;
      const userId = userRef.id;

      try {
        // FIX #5: Catch-up loop — process ALL missed periods, not just one
        let nextDueDate;
        if (item.lastProcessedDate) {
          nextDueDate = item.lastProcessedDate.toDate();
        } else if (item.startDate) {
          nextDueDate = item.startDate.toDate();
          // First run: process from start date
          nextDueDate = advanceDate(nextDueDate, item.frequency, -1); // step back so the loop advances to startDate
        } else {
          continue; // No start date, skip
        }

        // Process all missed periods up to today
        while (true) {
          nextDueDate = advanceDate(new Date(nextDueDate), item.frequency);
          const nextDueStart = new Date(nextDueDate);
          nextDueStart.setHours(0, 0, 0, 0);

          if (nextDueStart > today) break; // Caught up

          const type = item.type || "expense";
          const finalAmount = (type === "income") ? Math.abs(item.amount) : -Math.abs(item.amount);

          operations.push({
            type: 'create',
            ref: userRef.collection('transactions').doc(),
            data: {
              title: item.name, subtitle: item.name, amount: finalAmount,
              date: admin.firestore.Timestamp.fromDate(nextDueStart),
              icon: item.icon, colorHex: item.colorHex,
              note: `Recurring: ${item.frequency}` + (item.note ? ` - ${item.note}` : ""),
              type: type, source: 'recurring', userId: userId,
              createdAt: admin.firestore.FieldValue.serverTimestamp()
            }
          });

          operations.push({
            type: 'update',
            ref: doc.ref,
            data: { lastProcessedDate: admin.firestore.Timestamp.fromDate(nextDueStart) }
          });
        }
      } catch (err) {
        // FIX #5: Per-user error handling — one user's failure doesn't stop the batch
        console.error(`Error processing recurring for user ${userId}, doc ${doc.id}:`, err);
      }
    }

    // FIX #5: Sub-batch processing — split into chunks of MAX_ITEMS_PER_BATCH
    if (operations.length === 0) return null;

    const chunks = [];
    for (let i = 0; i < operations.length; i += MAX_ITEMS_PER_BATCH) {
      chunks.push(operations.slice(i, i + MAX_ITEMS_PER_BATCH));
    }

    console.log(`Processing ${operations.length} recurring ops in ${chunks.length} batch(es)`);

    for (const chunk of chunks) {
      const batch = db.batch();
      for (const op of chunk) {
        if (op.type === 'create') {
          batch.set(op.ref, op.data);
        } else {
          batch.update(op.ref, op.data);
        }
      }
      await batch.commit();
    }

    return null;
  } catch (error) {
    console.error('Error processing recurring:', error);
    return null;
  }
});

function advanceDate(date, frequency, multiplier = 1) {
  const d = new Date(date);
  switch (frequency) {
    case "Daily": d.setDate(d.getDate() + (1 * multiplier)); break;
    case "Weekly": d.setDate(d.getDate() + (7 * multiplier)); break;
    case "Bi-Weekly": d.setDate(d.getDate() + (14 * multiplier)); break;
    case "Yearly": d.setFullYear(d.getFullYear() + (1 * multiplier)); break;
    default: d.setMonth(d.getMonth() + (1 * multiplier)); break; // Monthly
  }
  return d;
}

// --- Gap #1 Fix: Cleanup stale friend_requests and group_invitations ---
// Runs weekly on Sunday at 3:00 AM
exports.cleanupStaleRequests = functions.pubsub.schedule('0 3 * * 0').onRun(async (context) => {
  const db = admin.firestore();
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  let deletedCount = 0;

  try {
    // 1. Cleanup old friend_requests (accepted or declined)
    const friendRequests = await db.collection('friend_requests')
      .where('status', 'in', ['accepted', 'declined'])
      .where('createdAt', '<', thirtyDaysAgo)
      .limit(500) // Safety limit per run
      .get();

    const batch1 = db.batch();
    friendRequests.docs.forEach(doc => {
      batch1.delete(doc.ref);
      deletedCount++;
    });
    if (!friendRequests.empty) await batch1.commit();

    // 2. Cleanup old group_invitations (accepted or declined)
    const groupInvitations = await db.collection('group_invitations')
      .where('status', 'in', ['accepted', 'declined'])
      .where('createdAt', '<', thirtyDaysAgo)
      .limit(500)
      .get();

    const batch2 = db.batch();
    groupInvitations.docs.forEach(doc => {
      batch2.delete(doc.ref);
      deletedCount++;
    });
    if (!groupInvitations.empty) await batch2.commit();

    console.log(`[Cleanup] Purged ${deletedCount} stale request(s)`);
    return null;
  } catch (error) {
    console.error('[Cleanup] Error purging stale requests:', error);
    return null;
  }
});
