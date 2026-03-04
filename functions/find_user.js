const admin = require('firebase-admin');

if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'financetracker-c628c' // Force the exact project ID
    });
}
const db = admin.firestore();

async function checkUserTx() {
    const userId = "28uvqPAOaXWS89adqC63aEQkb7X2"; // @hotxhit
    console.log(`Checking transactions for @hotxhit...\n`);

    try {
        const txSnapshot = await db.collection('users').doc(userId).collection('transactions').limit(3).get();
        if (txSnapshot.empty) {
            console.log("No transactions found.");
            return;
        }

        txSnapshot.forEach(doc => {
            const data = doc.data();
            console.log(`Transaction: ${doc.id}`);
            console.log(`- Title: ${data.title}`);
            console.log(`- Amount: ${data.amount}`);
            console.log(`- CategoryId: ${data.categoryId ? data.categoryId : "MISSING"}`);
            // Legacy fields:
            console.log(`- Subtitle: ${data.subtitle !== undefined ? data.subtitle : "Removed"}`);
            console.log(`- Icon: ${data.icon !== undefined ? data.icon : "Removed"}`);
            console.log(`- ColorHex: ${data.colorHex !== undefined ? data.colorHex : "Removed"}`);
            console.log("---");
        });

    } catch (e) {
        console.log(`Error: ${e.message}`);
    }
}

checkUserTx();
