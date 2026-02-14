const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');

exports.processRecurringTransactions = functions.pubsub.schedule('1 0 * * *').onRun(async (context) => {
  const db = admin.firestore();
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  try {
    const snapshot = await db.collectionGroup('recurringTransactions').get();
    if (snapshot.empty) return null;

    const batch = db.batch();
    let count = 0;

    for (const doc of snapshot.docs) {
      const item = doc.data();
      const userRef = doc.ref.parent.parent;
      if (!userRef) continue;
      const userId = userRef.id;

      let nextDueDate;
      if (item.lastProcessedDate) {
        nextDueDate = item.lastProcessedDate.toDate();
        switch (item.frequency) {
          case "Daily": nextDueDate.setDate(nextDueDate.getDate() + 1); break;
          case "Weekly": nextDueDate.setDate(nextDueDate.getDate() + 7); break;
          case "Bi-Weekly": nextDueDate.setDate(nextDueDate.getDate() + 14); break;
          case "Yearly": nextDueDate.setFullYear(nextDueDate.getFullYear() + 1); break;
          default: nextDueDate.setMonth(nextDueDate.getMonth() + 1); break;
        }
      } else {
        nextDueDate = item.startDate.toDate();
      }

      const nextDueStart = new Date(nextDueDate);
      nextDueStart.setHours(0, 0, 0, 0);

      if (nextDueStart <= today) {
        const type = item.type || "expense";
        const finalAmount = (type === "income") ? Math.abs(item.amount) : -Math.abs(item.amount);

        const newTxRef = userRef.collection('transactions').doc();
        batch.set(newTxRef, {
          title: item.name, subtitle: item.name, amount: finalAmount,
          date: admin.firestore.Timestamp.fromDate(nextDueStart),
          icon: item.icon, colorHex: item.colorHex,
          note: `Recurring: ${item.frequency}` + (item.note ? ` - ${item.note}` : ""),
          type: type, source: 'recurring', userId: userId,
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });

        batch.update(doc.ref, { lastProcessedDate: admin.firestore.Timestamp.fromDate(nextDueStart) });
        count++;
      }
    }

    if (count > 0) await batch.commit();
    return null;
  } catch (error) {
    console.error('Error processing recurring:', error);
    return null;
  }
});
