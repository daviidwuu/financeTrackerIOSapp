const admin = require('firebase-admin');

/**
 * Balance Backfill Script
 * 
 * One-time script to calculate and set the initial aggregatedIncome
 * and aggregatedExpense values for a user by summing ALL their transactions.
 * 
 * Usage (from functions/ directory):
 *   node -e "require('./src/balanceBackfill').backfillUser('USER_ID')"
 * 
 * Or for all users:
 *   node -e "require('./src/balanceBackfill').backfillAllUsers()"
 */

// Initialize admin if not already initialized
if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'financetracker-c628c'
    });
}

async function backfillUser(userId) {
    const db = admin.firestore();
    console.log(`Backfilling balance for user ${userId}...`);

    const transactionsSnapshot = await db
        .collection('users').doc(userId).collection('transactions')
        .get();

    let totalIncome = 0;
    let totalExpense = 0;

    transactionsSnapshot.docs.forEach(doc => {
        const tx = doc.data();
        const amount = Math.abs(tx.amount || 0);

        if (tx.type === 'income') {
            totalIncome += amount;
        } else {
            totalExpense += amount;
        }
    });

    await db.collection('users').doc(userId).update({
        aggregatedIncome: totalIncome,
        aggregatedExpense: totalExpense,
        lastBalanceAggregatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`User ${userId}: income=$${totalIncome.toFixed(2)}, expense=$${totalExpense.toFixed(2)}, net=$${(totalIncome - totalExpense).toFixed(2)} (${transactionsSnapshot.size} transactions)`);
}

async function backfillAllUsers() {
    const db = admin.firestore();
    const usersSnapshot = await db.collection('users').get();

    console.log(`Found ${usersSnapshot.size} users. Starting backfill...`);

    for (const userDoc of usersSnapshot.docs) {
        try {
            await backfillUser(userDoc.id);
        } catch (error) {
            console.error(`Failed to backfill user ${userDoc.id}:`, error);
        }
    }

    console.log('Backfill complete!');
}

module.exports = { backfillUser, backfillAllUsers };
