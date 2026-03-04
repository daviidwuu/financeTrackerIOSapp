const admin = require('firebase-admin');

process.env.GOOGLE_APPLICATION_CREDENTIALS = './functions/service-account-credentials.json';

admin.initializeApp({
    projectId: 'financetracker-c628c'
});

const db = admin.firestore();

async function migrateCategories() {
    console.log('--- Migrating Categories ---');
    const usersSnap = await db.collection('users').get();
    let totalCategories = 0;
    let modifiedCategories = 0;

    for (const doc of usersSnap.docs) {
        const budgetsRef = db.collection('users').doc(doc.id).collection('budgets');
        const budgetsSnap = await budgetsRef.get();
        for (const bDoc of budgetsSnap.docs) {
            const data = bDoc.data();
            totalCategories++;

            let needsUpdate = false;
            let updateData = {};

            if (!data.icon || data.icon.trim() === '') {
                updateData.icon = 'tag.fill';
                needsUpdate = true;
            }
            if (!data.colorHex || data.colorHex.trim() === '') {
                updateData.colorHex = '#808080';
                needsUpdate = true;
            }

            if (needsUpdate) {
                await budgetsRef.doc(bDoc.id).update(updateData);
                modifiedCategories++;
                console.log(`User: ${doc.id} - Updated Category: ${data.category} -> Set icon: ${updateData.icon || data.icon}, colorHex: ${updateData.colorHex || data.colorHex}`);
            }
        }
    }
    console.log(`Total Categories Processed: ${totalCategories}`);
    console.log(`Categories Migrated: ${modifiedCategories}`);
    console.log('--- Migration Complete ---');
}

migrateCategories().catch(console.error);
