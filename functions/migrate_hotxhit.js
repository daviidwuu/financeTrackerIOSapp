const admin = require('firebase-admin');

if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'financetracker-c628c' // Force the exact project ID
    });
}
const db = admin.firestore();

async function migrateUser() {
    const userId = "28uvqPAOaXWS89adqC63aEQkb7X2"; // @hotxhit

    console.log(`Migrating User: @hotxhit (UID: ${userId})...\n`);

    try {
        const userRef = db.collection('users').doc(userId);

        // Get transaction count
        const txSnapshot = await userRef.collection('transactions').get();
        console.log(`- Total Transactions Found: ${txSnapshot.size}`);

        // Fetch User's Budgets (Categories) to build lookup table
        const budgetsSnapshot = await userRef.collection('budgets').get();
        let categoryLookup = {};

        budgetsSnapshot.forEach(doc => {
            const data = doc.data();
            if (data.category) {
                categoryLookup[data.category.toLowerCase()] = doc.id;
            }
        });

        console.log(`- Found ${Object.keys(categoryLookup).length} Categories for lookup.`);

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

        console.log(`✅ Successfully Migrated ${userTxsMigrated} transactions for @hotxhit.`);

    } catch (e) {
        console.log(`Error: ${e.message}`);
    }
}

migrateUser();
