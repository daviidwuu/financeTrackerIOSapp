const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { getIconForCategory, getColorForCategory } = require('../helpers');
const { revenueCatWebhook } = require('./revenueCatWebhook');
const { redeemReward } = require('./redeemReward');

exports.revenueCatWebhook = revenueCatWebhook;
exports.redeemReward = redeemReward;

exports.addTransaction = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    // --- Gap #5 Fix: Verify Firebase Auth Token ---
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Missing or invalid Authorization header. Use: Bearer <Firebase ID Token>' });
      return;
    }

    const idToken = authHeader.split('Bearer ')[1];
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (authError) {
      console.error('[Auth] Token verification failed:', authError.message);
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }

    const { UserID, Data } = req.body;
    if (!UserID || !Data) {
      res.status(400).json({ error: 'Missing required fields' });
      return;
    }

    // Ensure the authenticated user matches the target UserID
    if (decodedToken.uid !== UserID) {
      res.status(403).json({ error: 'Token UID does not match UserID' });
      return;
    }

    const { Category, Type, Amount, Notes } = Data;
    const parsedAmount = parseFloat(Amount);
    if (isNaN(parsedAmount)) {
      res.status(400).json({ error: 'Invalid Amount' });
      return;
    }

    const transactionType = Type.toLowerCase();
    const finalAmount = transactionType === 'income' ? Math.abs(parsedAmount) : -Math.abs(parsedAmount);

    const transactionData = {
      title: Category, subtitle: Category, amount: finalAmount, date: new Date(),
      icon: getIconForCategory(Category), colorHex: getColorForCategory(Category),
      note: Notes || null, userId: UserID, type: transactionType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(), source: 'shortcuts'
    };

    const docRef = await admin.firestore().collection('users').doc(UserID).collection('transactions').add(transactionData);
    res.status(200).json({ success: true, transactionId: docRef.id });
  } catch (error) {
    console.error('Error adding transaction:', error);
    res.status(500).json({ error: 'Failed to process transaction' });
  }
});
