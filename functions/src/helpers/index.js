const admin = require('firebase-admin');

// Idempotency check: Returns true if event already processed
async function checkIdempotency(eventId) {
  const eventRef = admin.firestore().collection('processed_events').doc(eventId);
  try {
    const doc = await eventRef.get();
    if (doc.exists) {
      console.log(`Event ${eventId} already processed. Skipping.`);
      return true;
    }
    await eventRef.set({ processedAt: admin.firestore.FieldValue.serverTimestamp() });
    return false;
  } catch (e) {
    console.warn(`Idempotency check failed for ${eventId}:`, e);
    return false; // Fail safe: process it
  }
}

function getIconForCategory(category) {
  const categoryIcons = {
    'Dining': 'fork.knife', 'Groceries': 'cart.fill', 'Transportation': 'car.fill',
    'Shopping': 'bag.fill', 'Entertainment': 'tv.fill', 'Utilities': 'bolt.fill',
    'Health': 'heart.fill', 'Salary': 'dollarsign.circle.fill', 'Freelance': 'laptopcomputer'
  };
  return categoryIcons[category] || 'dollarsign.circle';
}

function getColorForCategory(category) {
  const categoryColors = {
    'Dining': '#FF6B6B', 'Groceries': '#4ECDC4', 'Transportation': '#45B7D1',
    'Shopping': '#FFA07A', 'Entertainment': '#98D8C8', 'Utilities': '#FFD93D',
    'Health': '#6BCF7F', 'Salary': '#4CAF50', 'Freelance': '#2196F3'
  };
  return categoryColors[category] || '#757575';
}

async function getUserInfo(uid) {
  const doc = await admin.firestore().collection('users').doc(uid).get();
  if (!doc.exists) return { name: 'Someone', username: 'user', fcmToken: null, avatarColor: '#808080' };
  const data = doc.data();
  return {
    name: data.name || data.displayName || 'Someone',
    username: data.username || 'user',
    fcmToken: data.fcmToken,
    avatarColor: data.avatarColor || '#808080'
  };
}

/**
 * Sends a push notification to a user via FCM.
 * Handles stale/invalid tokens by clearing them from the user profile.
 * @param {string} uid - Target user ID
 * @param {string} title - Notification title
 * @param {string} body - Notification body
 * @param {Object} data - Custom data payload (must be string values)
 * @param {string} [preloadedToken] - Optional pre-fetched FCM token to avoid redundant reads
 */
async function sendNotification(uid, title, body, data, preloadedToken) {
  const STALE_TOKEN_ERRORS = [
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
    'messaging/invalid-argument',
  ];

  try {
    const fcmToken = preloadedToken || (await getUserInfo(uid)).fcmToken;
    if (!fcmToken) {
      console.warn(`[FCM] No token for target user. Skipping notification.`);
      return;
    }

    // Ensure all data values are strings (FCM requirement)
    const stringData = {};
    if (data) {
      for (const [key, value] of Object.entries(data)) {
        stringData[key] = String(value ?? '');
      }
    }

    const message = {
      token: fcmToken,
      notification: { title, body },
      data: stringData,
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
            'mutable-content': 1,
          },
        },
      },
    };

    await admin.messaging().send(message);
    console.log(`[FCM] ✅ Sent notification | type=${stringData.type || 'unknown'}`);
  } catch (error) {
    const errorCode = error?.code || error?.errorInfo?.code || '';

    if (STALE_TOKEN_ERRORS.includes(errorCode)) {
      // Token is stale or invalid — clear it from user profile
      console.warn(`[FCM] ⚠️ Stale token detected (${errorCode}). Clearing fcmToken.`);
      try {
        await admin.firestore().collection('users').doc(uid).update({ fcmToken: admin.firestore.FieldValue.delete() });
      } catch (clearError) {
        console.error(`[FCM] Failed to clear stale token:`, clearError.message);
      }
    } else {
      console.error(`[FCM] ❌ Failed to send notification | Error: ${error.message || error}`);
    }
  }
}

module.exports = {
  checkIdempotency,
  getIconForCategory,
  getColorForCategory,
  getUserInfo,
  sendNotification
};
