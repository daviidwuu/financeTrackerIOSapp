const admin = require('firebase-admin');

// 1. Initialize Firebase Admin
if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'financetracker-c628c' // Force the exact project ID
    });
}
const db = admin.firestore();

// 2. Main Migration Logic
async function runMigration() {
    console.log("🚀 Starting Production Data Migration (Rule: Users > 10 transactions only)");

    try {
        // Fetch all users
        const usersSnapshot = await db.collection('users').get();
        console.log(`Found ${usersSnapshot.size} total users in the database.\n`);

        let totalUsersMigrated = 0;
        let totalTransactionsMigrated = 0;

        for (const userDoc of usersSnapshot.docs) {
            const userId = userDoc.id;
            const userRef = db.collection('users').doc(userId);

            // Check Transaction Count
            const txSnapshot = await userRef.collection('transactions').get();
            const txCount = txSnapshot.size;

            if (txCount === 0) {
                console.log(`- Skipping User ${userId}: No transactions.`);
                continue;
            }

            console.log(`\n======================================================`);
            console.log(`- Migrating User ${userId} (${txCount} transactions)`);
            console.log(`======================================================`);

            // Fetch User's Budgets (Categories) to build lookup table
            const budgetsSnapshot = await userRef.collection('budgets').get();
            let categoryLookup = {};

            budgetsSnapshot.forEach(doc => {
                const data = doc.data();
                if (data.category) {
                    categoryLookup[data.category.toLowerCase()] = doc.id;
                }
            });

            // Migrate Transactions in Batches
            let batch = db.batch();
            let operationsInBatch = 0;
            let userTxsMigrated = 0;

            for (const txDoc of txSnapshot.docs) {
                const txData = txDoc.data();
                const txRef = txDoc.ref;

                let updates = {};

                // 1. Backfill categoryId if missing
                if (!txData.categoryId && txData.subtitle) {
                    const matchedId = categoryLookup[txData.subtitle.toLowerCase()];
                    if (matchedId) {
                        updates.categoryId = matchedId;
                    }
                }

                // 2. Mark legacy fields for deletion
                if (txData.subtitle !== undefined) updates.subtitle = admin.firestore.FieldValue.delete();
                if (txData.icon !== undefined) updates.icon = admin.firestore.FieldValue.delete();
                if (txData.colorHex !== undefined) updates.colorHex = admin.firestore.FieldValue.delete();

                if (Object.keys(updates).length > 0) {
                    batch.update(txRef, updates);
                    operationsInBatch++;
                    userTxsMigrated++;
                }

                // Commit if we hit the 500 operation limit
                if (operationsInBatch >= 450) {
                    await batch.commit();
                    batch = db.batch();
                    operationsInBatch = 0;
                }
            }

            if (operationsInBatch > 0) {
                await batch.commit();
            }

            console.log(`  -> Migrated ${userTxsMigrated} transactions for user ${userId}.`);
            totalUsersMigrated++;
            totalTransactionsMigrated += userTxsMigrated;
        }

        console.log(`\n✅ Migration Complete!`);
        console.log(`Migrated ${totalUsersMigrated} users and ${totalTransactionsMigrated} total transactions.`);

    } catch (e) {
        console.error("Migration Error:", e);
    }
}

runMigration();
