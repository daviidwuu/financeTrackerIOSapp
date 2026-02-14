const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { getIconForCategory, getColorForCategory } = require('../helpers');

exports.addTransaction = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { UserID, Data } = req.body;
    if (!UserID || !Data) {
      res.status(400).json({ error: 'Missing required fields' });
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
    res.status(500).json({ error: error.message });
  }
});
