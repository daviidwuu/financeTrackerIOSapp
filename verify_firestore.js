const admin = require('./functions/node_modules/firebase-admin');


// Initialize with the same service account we used for functions
process.env.GOOGLE_APPLICATION_CREDENTIALS = './functions/service-account-credentials.json';
// Note: We might not have the JSON file locally if we used setGlobalOptions in code. 
// We'll rely on ADC or we need to assume we can run this with `firebase functions:shell` or similar, 
// OR simpler: use the existing admin initialized in index.js but run it as a standalone script? 
// Actually, safest is to use `firebase-admin` with ADC (Application Default Credentials) if gcloud is auth'd.
// Let's assume gcloud auth application-default login is needed OR we just try to read.

admin.initializeApp({
    projectId: 'financetracker-c628c'
});

const db = admin.firestore();

async function checkRecentActivity() {
    console.log('--- Checking Users and FCM Tokens ---');
    const usersSnap = await db.collection('users').get();

    for (const doc of usersSnap.docs) {
        const data = doc.data();
        console.log(`User: ${doc.id} (${data.displayName || 'No Name'})`);
        console.log(`   FCM Token: ${data.fcmToken ? data.fcmToken.substring(0, 10) + '...' : 'MISSING'}`);

        // Check requests for this user
        const requestsSnap = await db.collection('users').doc(doc.id).collection('requests')
            .orderBy('createdAt', 'desc')
            .limit(3)
            .get();

        if (!requestsSnap.empty) {
            console.log('   Recent Requests received:');
            requestsSnap.forEach(req => {
                const reqData = req.data();
                console.log(`      - ID: ${req.id} | From: ${reqData.requesterName} | Amount: ${reqData.amount} | Status: ${reqData.status} | Time: ${reqData.createdAt.toDate().toISOString()}`);
            });
        } else {
            console.log('   No requests received.');
        }
        console.log('');
    }
}

checkRecentActivity().catch(console.error);
