const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

/**
 * RevenueCat Webhook Handler
 *
 * Handles subscription lifecycle events from RevenueCat.
 * On EXPIRATION or CANCELLATION: deletes auto-created recurring transactions
 * and updates the user's premium status.
 *
 * Setup: Configure this URL in RevenueCat Dashboard > Integrations > Webhooks
 * (Optional) Set Authorization header in RevenueCat to match environment variable REVENUECAT_WEBHOOK_AUTH_KEY
 */
exports.revenueCatWebhook = functions.https.onRequest(async (req, res) => {
    if (req.method !== 'POST') {
        res.status(405).json({ error: 'Method not allowed' });
        return;
    }

    // Optional: Validate webhook authorization via environment variable
    const expectedAuth = process.env.REVENUECAT_WEBHOOK_AUTH_KEY;
    if (expectedAuth) {
        const authHeader = req.headers.authorization;
        if (authHeader !== `Bearer ${expectedAuth}`) {
            console.warn('[RevenueCat Webhook] Invalid authorization header');
            res.status(401).json({ error: 'Unauthorized' });
            return;
        }
    }

    try {
        const event = req.body;
        const eventType = event.event?.type;
        const appUserId = event.event?.app_user_id;

        console.log(`[RevenueCat Webhook] Event: ${eventType}, User: ${appUserId}`);

        if (!appUserId) {
            res.status(400).json({ error: 'Missing app_user_id' });
            return;
        }

        // Handle subscription end events
        const cancellationEvents = [
            'EXPIRATION',
            'CANCELLATION',
            'NON_RENEWING_PURCHASE',  // One-time purchase expired
            'BILLING_ISSUE',          // Payment failed
        ];

        if (cancellationEvents.includes(eventType)) {
            const db = admin.firestore();

            // 1. Delete auto-created recurring transactions
            const recurringSnapshot = await db
                .collection('users')
                .doc(appUserId)
                .collection('recurringTransactions')
                .where('source', '==', 'subscription')
                .get();

            if (!recurringSnapshot.empty) {
                const batch = db.batch();
                recurringSnapshot.docs.forEach(doc => batch.delete(doc.ref));
                await batch.commit();
                console.log(`[RevenueCat Webhook] Deleted ${recurringSnapshot.size} subscription recurring transaction(s) for ${appUserId}`);
            }

            // 2. Update premium status
            if (eventType === 'EXPIRATION') {
                await db.collection('users').doc(appUserId).update({
                    isPremium: false
                });
                console.log(`[RevenueCat Webhook] Set isPremium=false for ${appUserId}`);
            }
        }

        // Always return 200 to acknowledge receipt
        res.status(200).json({ status: 'ok' });
    } catch (error) {
        console.error('[RevenueCat Webhook] Error:', error);
        // Still return 200 to prevent RevenueCat from retrying
        res.status(200).json({ status: 'error', message: error.message });
    }
});
