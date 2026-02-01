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

/**
 * Cloud Function to process recurring transactions daily
 * Runs every day at 00:01 UTC
 */
exports.processRecurringTransactions = functions.pubsub.schedule('1 0 * * *').onRun(async (context) => {
  const db = admin.firestore();
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()); // 00:00:00 today

  console.log('Processing recurring transactions for date:', today.toISOString());

  try {
    // Query all recurring transactions using Collection Group Query
    // This finds all documents in any collection named 'recurringTransactions'
    const snapshot = await db.collectionGroup('recurringTransactions').get();

    if (snapshot.empty) {
      console.log('No recurring transactions found.');
      return null;
    }

    const batch = db.batch();
    let operationCount = 0;

    for (const doc of snapshot.docs) {
      const item = doc.data();
      const itemId = doc.id;
      // The parent of 'recurringTransactions' is the user document: users/{userId}
      // doc.ref.parent is the collection, doc.ref.parent.parent is the user doc
      const userRef = doc.ref.parent.parent;
      if (!userRef) continue;
      const userId = userRef.id;

      let nextDueDate;
      let lastProcessed = item.lastProcessedDate ? item.lastProcessedDate.toDate() : null;

      if (lastProcessed) {
        // Calculate next due date based on frequency from last processed date
        nextDueDate = new Date(lastProcessed);
        switch (item.frequency) {
          case "Daily":
            nextDueDate.setDate(nextDueDate.getDate() + 1);
            break;
          case "Weekly":
            nextDueDate.setDate(nextDueDate.getDate() + 7);
            break;
          case "Bi-Weekly":
            nextDueDate.setDate(nextDueDate.getDate() + 14);
            break;
          case "Yearly":
            nextDueDate.setFullYear(nextDueDate.getFullYear() + 1);
            break;
          default: // "Monthly"
            nextDueDate.setMonth(nextDueDate.getMonth() + 1);
            break;
        }
      } else {
        // First time: use startDate
        nextDueDate = item.startDate.toDate();
      }

      // Normalize nextDueDate to Start of Day for comparison
      const nextDueStartOfDay = new Date(nextDueDate.getFullYear(), nextDueDate.getMonth(), nextDueDate.getDate());

      // Check if due (nextDueStartOfDay <= today)
      if (nextDueStartOfDay <= today) {
        console.log(`Processing item ${item.name} for user ${userId}. Due: ${nextDueStartOfDay.toISOString()}`);

        const transactionDate = nextDueStartOfDay; // Use the calculated due date as the transaction date

        // 1. Create the Transaction Data
        // Handle Expense vs Income logic
        let amount = item.amount;
        // Logic from Swift:
        // if item.type == "income" ? amount : -abs(amount)
        const type = item.type || "expense";
        const finalAmount = (type === "income") ? Math.abs(amount) : -Math.abs(amount);

        const newTransactionRef = userRef.collection('transactions').doc();
        const newTransaction = {
          title: item.name,
          subtitle: item.name,
          amount: finalAmount,
          date: admin.firestore.Timestamp.fromDate(transactionDate),
          icon: item.icon,
          colorHex: item.colorHex || '#000000',
          note: `Recurring: ${item.frequency}` + (item.note ? ` - ${item.note}` : ""),
          type: type,
          source: 'recurring',
          userId: userId,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        };

        batch.set(newTransactionRef, newTransaction);

        // 2. Update the RecurringTransaction
        // We set lastProcessedDate to the date we just "paid" for/processed.
        // This ensures the next run calculates from THIS date.
        batch.update(doc.ref, {
          lastProcessedDate: admin.firestore.Timestamp.fromDate(transactionDate)
        });

        operationCount++;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
      console.log(`Successfully processed ${operationCount} recurring transactions.`);
    } else {
      console.log('No recurring transactions due today.');
    }

    return null;

  } catch (error) {
    console.error('Error processing recurring transactions:', error);
    return null;
  }
});
