const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Cloud Function to add transactions via Apple Shortcuts
 * 
 * POST https://us-central1-YOUR-PROJECT.cloudfunctions.net/addTransaction
 * 
 * Request Body:
 * {
 *   "userId": "firebase-user-id",
 *   "amount": 25.50,
 *   "category": "Dining",
 *   "type": "expense",  // "expense" or "income"
 *   "note": "Optional note",
 *   "date": "2025-12-16T11:30:00Z"
 * }
 */
exports.addTransaction = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');

  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.set('Access-Control-Max-Age', '3600');
    res.status(204).send('');
    return;
  }

  // Only allow POST
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    // Parse nested dictionary: { UserID: "...", Data: { Category, Type, Amount, Notes } }
    const { UserID, Data } = req.body;

    // Validate required fields
    if (!UserID || !Data) {
      res.status(400).json({
        error: 'Missing required fields',
        required: { UserID: 'string', Data: { Category: 'string', Type: 'string', Amount: 'number', Notes: 'string' } }
      });
      return;
    }

    const { Category, Type, Amount, Notes } = Data;

    // Validate data fields
    if (!Category || !Type || Amount === undefined) {
      res.status(400).json({
        error: 'Missing required Data fields',
        required: ['Category', 'Type', 'Amount']
      });
      return;
    }

    // Validate userId exists in Firebase Auth
    try {
      await admin.auth().getUser(UserID);
    } catch (error) {
      res.status(401).json({ error: 'Invalid UserID' });
      return;
    }

    // Validate amount
    const parsedAmount = parseFloat(Amount);
    if (isNaN(parsedAmount)) {
      res.status(400).json({ error: 'Invalid Amount' });
      return;
    }

    // Prepare transaction data
    const transactionType = Type.toLowerCase();
    const finalAmount = transactionType === 'income'
      ? Math.abs(parsedAmount)
      : -Math.abs(parsedAmount);

    const transactionData = {
      title: Category,
      subtitle: Category,
      amount: finalAmount,
      date: new Date(),
      icon: getIconForCategory(Category),
      colorHex: getColorForCategory(Category),
      note: Notes || null,
      userId: UserID,
      type: transactionType,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'shortcuts'
    };

    // Add to Firestore
    const docRef = await admin.firestore()
      .collection('users')
      .doc(UserID)
      .collection('transactions')
      .add(transactionData);

    // Success response
    res.status(200).json({
      success: true,
      message: `Transaction added successfully`,
      transactionId: docRef.id,
      data: {
        amount: finalAmount,
        category: Category,
        type: transactionType
      }
    });

  } catch (error) {
    console.error('Error adding transaction:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error.message
    });
  }
});

// Helper function to get default icon for category
function getIconForCategory(category) {
  const categoryIcons = {
    'Dining': 'fork.knife',
    'Groceries': 'cart.fill',
    'Transportation': 'car.fill',
    'Shopping': 'bag.fill',
    'Entertainment': 'tv.fill',
    'Utilities': 'bolt.fill',
    'Health': 'heart.fill',
    'Salary': 'dollarsign.circle.fill',
    'Freelance': 'laptopcomputer'
  };
  return categoryIcons[category] || 'dollarsign.circle';
}

// Helper function to get default color for category
function getColorForCategory(category) {
  const categoryColors = {
    'Dining': '#FF6B6B',
    'Groceries': '#4ECDC4',
    'Transportation': '#45B7D1',
    'Shopping': '#FFA07A',
    'Entertainment': '#98D8C8',
    'Utilities': '#FFD93D',
    'Health': '#6BCF7F',
    'Salary': '#4CAF50',
    'Freelance': '#2196F3'
  };
  return categoryColors[category] || '#757575';
}
