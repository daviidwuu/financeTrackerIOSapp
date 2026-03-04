const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

/**
 * Budget Aggregator — Cloud Function
 * 
 * Triggers on any write (create/update/delete) to a user's transactions.
 * Recalculates the `currentPeriodSpent` for the affected budget(s)
 * and writes it directly to the budget document.
 * 
 * This moves the heavy aggregation work to the server so the app
 * only needs to read a single number instead of fetching all transactions.
 */
exports.v2_onTransactionWritten = onDocumentWritten(
    'users/{userId}/transactions/{transactionId}',
    async (event) => {
        const userId = event.params.userId;
        const db = admin.firestore();

        const beforeData = event.data.before?.data();
        const afterData = event.data.after?.data();

        // ── 1. Budget Aggregation (existing logic) ──
        const affectedCategoryIds = new Set();

        if (beforeData?.categoryId) affectedCategoryIds.add(beforeData.categoryId);
        if (afterData?.categoryId) affectedCategoryIds.add(afterData.categoryId);

        if (affectedCategoryIds.size === 0) {
            console.log(`Transaction ${event.params.transactionId} has no categoryId. Recalculating all budgets.`);
            const allBudgets = await db.collection('users').doc(userId).collection('budgets').get();
            allBudgets.docs.forEach(doc => affectedCategoryIds.add(doc.id));
        }

        // Budget recalculation (skip if no budgets, but still do balance)
        if (affectedCategoryIds.size > 0) {
            console.log(`Recalculating ${affectedCategoryIds.size} budget(s) for user ${userId}`);
            const budgetPromises = Array.from(affectedCategoryIds).map(async (budgetId) => {
                try {
                    await recalculateBudgetSpent(db, userId, budgetId);
                } catch (error) {
                    console.error(`Failed to recalculate budget ${budgetId} for user ${userId}:`, error);
                }
            });
            await Promise.all(budgetPromises);
        }

        // ── 2. Balance Aggregation (NEW) ──
        // Uses atomic FieldValue.increment() for delta-based updates.
        // Handles create, update (type/amount change), and delete.
        try {
            let incomeDelta = 0;
            let expenseDelta = 0;

            // Reverse the old transaction (if existed)
            if (beforeData) {
                const oldAmount = Math.abs(beforeData.amount || 0);
                if (beforeData.type === 'income') {
                    incomeDelta -= oldAmount;
                } else {
                    expenseDelta -= oldAmount;
                }
            }

            // Apply the new transaction (if exists)
            if (afterData) {
                const newAmount = Math.abs(afterData.amount || 0);
                if (afterData.type === 'income') {
                    incomeDelta += newAmount;
                } else {
                    expenseDelta += newAmount;
                }
            }

            // Only write if there's an actual change
            if (incomeDelta !== 0 || expenseDelta !== 0) {
                const userRef = db.collection('users').doc(userId);
                const updateData = {
                    lastBalanceAggregatedAt: admin.firestore.FieldValue.serverTimestamp(),
                };
                if (incomeDelta !== 0) {
                    updateData.aggregatedIncome = admin.firestore.FieldValue.increment(incomeDelta);
                }
                if (expenseDelta !== 0) {
                    updateData.aggregatedExpense = admin.firestore.FieldValue.increment(expenseDelta);
                }
                await userRef.update(updateData);
                console.log(`Balance updated for user ${userId}: income delta=${incomeDelta}, expense delta=${expenseDelta}`);
            }
        } catch (error) {
            console.error(`Failed to update balance for user ${userId}:`, error);
        }
    }
);

/**
 * Recalculates the total spent for a specific budget in its current period.
 * 
 * Uses the budget's `frequency` and `monthStartDate` to determine the
 * current period window, then sums all matching transactions.
 */
async function recalculateBudgetSpent(db, userId, budgetId) {
    // 1. Get the budget document
    const budgetRef = db.collection('users').doc(userId).collection('budgets').doc(budgetId);
    const budgetDoc = await budgetRef.get();

    if (!budgetDoc.exists) {
        console.warn(`Budget ${budgetId} not found for user ${userId}`);
        return;
    }

    const budget = budgetDoc.data();
    const category = budget.category;
    const frequency = budget.frequency || 'Monthly';
    const monthStartDate = budget.monthStartDate?.toDate() || new Date();

    // 2. Calculate the current period window
    const window = calculatePeriodWindow(frequency, monthStartDate);

    // 3. Query transactions matching this budget's category within the period
    const transactionsSnapshot = await db
        .collection('users').doc(userId).collection('transactions')
        .where('date', '>=', window.start)
        .where('date', '<', window.end)
        .get();

    // 4. Sum the amounts (only for matching category)
    let netDiff = 0;
    transactionsSnapshot.docs.forEach(doc => {
        const tx = doc.data();
        // Match by categoryId (primary) or subtitle (legacy fallback)
        const matchesByIdReference = tx.categoryId === budgetId;
        const matchesByLegacyName = !tx.categoryId && tx.subtitle === category;

        if (matchesByIdReference || matchesByLegacyName) {
            netDiff += tx.amount; // amount is negative for expenses
        }
    });

    // If netDiff is -25 (Net Expense), Spent = 25
    // If netDiff is +10 (Net Profit), Spent = 0
    const spent = netDiff < 0 ? Math.abs(netDiff) : 0;

    // 5. Write the pre-calculated spent to the budget document
    await budgetRef.update({
        currentPeriodSpent: spent,
        lastAggregatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Budget "${category}" (${budgetId}): spent = $${spent.toFixed(2)}`);
}

/**
 * Calculates the current period window based on frequency and anchor date.
 * Mirrors the Swift `BudgetPeriodCalculator` logic.
 */
function calculatePeriodWindow(frequency, anchor) {
    const now = new Date();

    switch (frequency) {
        case 'Weekly': {
            const anchorWeekStart = startOfWeek(anchor);
            const nowWeekStart = startOfWeek(now);
            const weeksDiff = Math.floor((nowWeekStart - anchorWeekStart) / (7 * 24 * 60 * 60 * 1000));
            const start = new Date(anchorWeekStart.getTime() + weeksDiff * 7 * 24 * 60 * 60 * 1000);
            const end = new Date(start.getTime() + 7 * 24 * 60 * 60 * 1000);
            return { start, end };
        }
        case 'Bi-Weekly': {
            const anchorWeekStart = startOfWeek(anchor);
            const nowWeekStart = startOfWeek(now);
            const weeksDiff = Math.floor((nowWeekStart - anchorWeekStart) / (7 * 24 * 60 * 60 * 1000));
            const periods = Math.floor(weeksDiff / 2);
            const start = new Date(anchorWeekStart.getTime() + periods * 2 * 7 * 24 * 60 * 60 * 1000);
            const end = new Date(start.getTime() + 14 * 24 * 60 * 60 * 1000);
            return { start, end };
        }
        case 'Yearly': {
            const start = new Date(now.getFullYear(), anchor.getMonth(), anchor.getDate());
            if (start > now) {
                start.setFullYear(start.getFullYear() - 1);
            }
            const end = new Date(start);
            end.setFullYear(end.getFullYear() + 1);
            return { start, end };
        }
        default: { // Monthly
            const anchorDay = anchor.getDate();
            const start = new Date(now.getFullYear(), now.getMonth(), Math.min(anchorDay, daysInMonth(now.getFullYear(), now.getMonth())));
            if (start > now) {
                // Backtrack to previous month
                start.setMonth(start.getMonth() - 1);
                start.setDate(Math.min(anchorDay, daysInMonth(start.getFullYear(), start.getMonth())));
            }
            const end = new Date(start);
            end.setMonth(end.getMonth() + 1);
            return { start, end };
        }
    }
}

function startOfWeek(date) {
    const d = new Date(date);
    const day = d.getDay(); // 0 = Sunday
    d.setDate(d.getDate() - day);
    d.setHours(0, 0, 0, 0);
    return d;
}

function daysInMonth(year, month) {
    return new Date(year, month + 1, 0).getDate();
}
