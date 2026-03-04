const admin = require('./functions/node_modules/firebase-admin');

// Ensure you have auth, e.g. run with GOOGLE_APPLICATION_CREDENTIALS set if needed
try {
    admin.initializeApp();
} catch (e) {
    if (e.code !== 'app/duplicate-app') {
        throw e;
    }
}

const db = admin.firestore();

async function checkCurrentMonth() {
    console.log('--- Checking Transactions for Current Month ---');

    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);

    console.log(`Querying from ${startOfMonth.toISOString()} to ${nextMonth.toISOString()}`);

    // Pick the first user or a hardcoded user to test
    const usersSnap = await db.collection('users').limit(1).get();
    if (usersSnap.empty) {
        console.log('No users found.');
        return;
    }

    for (const doc of usersSnap.docs) {
        console.log(`User: ${doc.id}`);

        const txSnap = await db.collection('users').doc(doc.id).collection('transactions')
            .where('date', '>=', startOfMonth)
            .where('date', '<', nextMonth)
            .orderBy('date', 'desc')
            .get();

        console.log(`Found ${txSnap.size} transactions in the current month.`);

        txSnap.forEach(t => {
            const data = t.data();
            console.log(`  - TX: ${t.id} | Date: ${data.date.toDate().toISOString()} | Amount: ${data.amount}`);
        });

        // Also query ALL transactions and see dates
        const allTxSnap = await db.collection('users').doc(doc.id).collection('transactions')
            .orderBy('date', 'desc')
            .limit(10)
            .get();

        console.log(`\nHere are the 10 most recent transactions overall:`);
        allTxSnap.forEach(t => {
            const data = t.data();
            console.log(`  - TX: ${t.id} | Date: ${data.date.toDate().toISOString()} | Amount: ${data.amount}`);
        });
    }
}

checkCurrentMonth().catch(console.error);
