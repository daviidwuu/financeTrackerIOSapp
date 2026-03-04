const admin = require('firebase-admin');

if (!admin.apps.length) {
    admin.initializeApp({
        projectId: 'financetracker-c628c' // Force the exact project ID
    });
}

const db = admin.firestore();

async function checkMarchTransactions() {
    try {
        const userId = 'cjLSYiC4ksYKcBBs3q1EPJB6VCF3';
        console.log(`Checking user: ${userId} in project: ${admin.app().options.projectId}`);

        const start = new Date(2026, 2, 1); // March 1, 2026
        const end = new Date(2026, 3, 1);   // April 1, 2026

        console.log(`Checking dates between ${start.toISOString()} and ${end.toISOString()}`);

        const snapshot = await db.collection(`users/${userId}/transactions`)
            .get();

        console.log(`Found ${snapshot.size} TOTAL transactions for this user of all time.`);

        let marchCount = 0;
        let totalExpense = 0;
        let totalIncome = 0;
        let pureExpense = 0;
        let reimbursements = 0;

        snapshot.forEach(doc => {
            const data = doc.data();

            // Safely parse date
            let txDate = null;
            if (data.date) {
                if (typeof data.date.toDate === 'function') {
                    txDate = data.date.toDate();
                } else if (data.date instanceof Date) {
                    txDate = data.date;
                } else if (typeof data.date === 'string') {
                    txDate = new Date(data.date);
                }
            }

            if (txDate && txDate >= start && txDate < end) {
                marchCount++;
                console.log(`- Tx: [${doc.id}] ${data.title} | ${data.type} | $${data.amount} | Date: ${txDate.toISOString()} | Category: ${data.categoryId || data.subtitle}`);

                if (data.type === 'expense') {
                    totalExpense += Math.abs(data.amount);
                    pureExpense += Math.abs(data.amount);
                }
                if (data.type === 'income') {
                    totalIncome += Math.abs(data.amount);
                    if (data.subtitle !== 'Income' && data.subtitle !== 'Salary') {
                        reimbursements += Math.abs(data.amount);
                    }
                }
            }
        });

        console.log(`\nFound ${marchCount} transactions matching MARCH.`);
        console.log(`Total Expense in DB: $${totalExpense}`);
        console.log(`Total Income in DB:  $${totalIncome}`);
        console.log(`\nHomeView 'totalSpent' Calculation:`);
        console.log(`Pure Expenses:  $${pureExpense}`);
        console.log(`Reimbursements: $${reimbursements} (Income that is not 'Income' or 'Salary')`);
        console.log(`Net Spent:      $${Math.max(0, pureExpense - reimbursements)}`);

    } catch (e) {
        console.error("Error:", e);
    }
}

checkMarchTransactions();
