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

async function sendNotification(uid, title, body, data) {
  try {
    const { fcmToken } = await getUserInfo(uid);
    if (!fcmToken) return;

    const message = {
      token: fcmToken,
      notification: { title, body },
      data: data,
      apns: { payload: { aps: { sound: 'default', badge: 1 } } }
    };
    await admin.messaging().send(message);
    console.log(`Notification sent to ${uid}: ${title}`);
  } catch (error) {
    console.error(`Error sending notification to ${uid}:`, error);
  }
}

module.exports = {
  checkIdempotency,
  getIconForCategory,
  getColorForCategory,
  getUserInfo,
  sendNotification
};
