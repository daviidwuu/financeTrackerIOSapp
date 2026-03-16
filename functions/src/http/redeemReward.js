const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

/**
 * Cloud Function: redeemReward
 * 
 * Validates user auth, checks points balance server-side,
 * deducts points atomically, and generates a redemption record.
 * 
 * Future: integrate with Rewardz SPUR or PayPal Payouts API
 * to return real voucher codes or send real money.
 */
exports.redeemReward = functions.https.onCall(async (data, context) => {
  // 1. Auth check
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be signed in to redeem rewards.');
  }

  const userId = context.auth.uid;
  const { rewardId, rewardTitle, rewardIcon, cost, partnerName } = data;

  // 2. Validate input
  if (!rewardId || !rewardTitle || !cost || typeof cost !== 'number' || cost <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing or invalid reward data.');
  }

  const db = admin.firestore();
  const userRef = db.collection('users').doc(userId);

  try {
    // 3. Atomic transaction: check balance + deduct + create redemption
    const result = await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      
      if (!userDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'User not found.');
      }

      const currentPoints = userDoc.data().points || 0;
      
      if (currentPoints < cost) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `Insufficient points. You have ${currentPoints} but need ${cost}.`
        );
      }

      // Rate limiting: check if user redeemed this reward in the last 5 minutes
      const recentRedemptions = await db
        .collection('users')
        .doc(userId)
        .collection('redemptions')
        .where('rewardId', '==', rewardId)
        .orderBy('date', 'desc')
        .limit(1)
        .get();

      if (!recentRedemptions.empty) {
        const lastRedemption = recentRedemptions.docs[0].data();
        const lastDate = lastRedemption.date?.toDate?.() || new Date(0);
        const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
        
        if (lastDate > fiveMinutesAgo) {
          throw new functions.https.HttpsError(
            'resource-exhausted',
            'Please wait a few minutes before redeeming the same reward again.'
          );
        }
      }

      // Generate redemption code
      // TODO: Replace with real API call to Rewardz SPUR or PayPal Payouts
      const code = generateRedemptionCode();
      const now = new Date();
      
      // Calculate expiry (default 30 days)
      const expiryDays = 30;
      const expiresAt = new Date(now.getTime() + expiryDays * 24 * 60 * 60 * 1000);

      const redemptionId = db.collection('_').doc().id; // Generate unique ID
      const redemptionRef = userRef.collection('redemptions').doc(redemptionId);

      // Deduct points
      transaction.update(userRef, {
        points: admin.firestore.FieldValue.increment(-cost)
      });

      // Create redemption record
      transaction.set(redemptionRef, {
        id: redemptionId,
        rewardId,
        rewardTitle,
        rewardIcon: rewardIcon || 'gift.fill',
        cost,
        date: admin.firestore.Timestamp.fromDate(now),
        code,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        status: 'active',
        partnerName: partnerName || 'Partner'
      });

      return { code, redemptionId, expiresAt: expiresAt.toISOString() };
    });

    console.log(`[Redeem] User ${userId} redeemed ${rewardId} for ${cost} points. Code: ${result.code}`);

    return {
      success: true,
      code: result.code,
      redemptionId: result.redemptionId,
      expiresAt: result.expiresAt,
      message: `Reward redeemed! Your code is ${result.code}`
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error(`[Redeem] Error for user ${userId}:`, error);
    throw new functions.https.HttpsError('internal', 'Redemption failed. Please try again.');
  }
});

/**
 * Generates a random 8-character alphanumeric code.
 * TODO: Replace with real voucher code from partner API.
 */
function generateRedemptionCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}
