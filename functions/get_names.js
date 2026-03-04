const admin = require('firebase-admin');

if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'financetracker-c628c' // Force the exact project ID
    });
}
const db = admin.firestore();

async function getProfileNames() {
    const userIds = [
        '7JwpecQjvfTSvQfAKwLqOYUhAZb2',
        'kBgsT1jmFWcnS0npAdF16ny3wCp1',
        'nyx5cESdGFa2MQhyQ9sOU4sQU9B2'
    ];

    console.log("Fetching profile names for migrated users...\n");

    for (const uid of userIds) {
        try {
            const userDoc = await db.collection('users').doc(uid).get();
            if (userDoc.exists) {
                const data = userDoc.data();
                console.log(`- UID: ${uid}`);
                console.log(`  Name: ${data.name || data.firstName || data.username || "Unknown Name"}`);
                console.log(`  Username: @${data.username || "unknown"}`);
                console.log(`  Email: ${data.email || "No email stored"}\n`);
            } else {
                console.log(`- UID: ${uid} (User document not found)`);
            }
        } catch (e) {
            console.log(`- UID: ${uid} (Error: ${e.message})`);
        }
    }
}

getProfileNames();
