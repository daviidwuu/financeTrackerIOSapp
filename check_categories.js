const admin = require('./functions/node_modules/firebase-admin');

process.env.GOOGLE_APPLICATION_CREDENTIALS = './functions/service-account-credentials.json';

admin.initializeApp({
    projectId: 'financetracker-c628c'
});

const db = admin.firestore();

async function checkCategories() {
    console.log('--- Checking Categories ---');
    const usersSnap = await db.collection('users').get();
    let totalCategories = 0;
    let missingIcons = 0;

    for (const doc of usersSnap.docs) {
        const budgetsSnap = await db.collection('users').doc(doc.id).collection('budgets').get();
        for (const bDoc of budgetsSnap.docs) {
            const data = bDoc.data();
            totalCategories++;
            if (!data.icon || !data.colorHex) {
                missingIcons++;
                console.log(`User: ${doc.id} - Category: ${data.category} is missing icon/colorHex`);
            }
        }
    }
    console.log(`Total Categories: ${totalCategories}`);
    console.log(`Categories missing icons: ${missingIcons}`);
}

checkCategories().catch(console.error);
