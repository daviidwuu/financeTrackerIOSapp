#!/usr/bin/env node
/**
 * One-off server-side migration script for ALL users.
 *
 * What it does (mirrors DataMigrationManager.swift):
 *   Phase 1 – Transactions:
 *     • Backfills `categoryId` using subtitle → category name lookup
 *     • Deletes legacy fields: subtitle, icon, colorHex
 *   Phase 2 – Split Requests:
 *     • Deletes legacy fields: fromName, toName
 *   Phase 3 – Group Transactions:
 *     • Deletes legacy fields: payerName, receiverName, category, icon, colorHex
 *
 * Usage:
 *   cd functions
 *   node src/migrate-all-users.js
 *
 * Prerequisites:
 *   • GOOGLE_APPLICATION_CREDENTIALS env var pointing to your service account key JSON
 *     OR run from a machine already authenticated via `firebase login`
 *   • `npm install` in the functions directory
 */

const admin = require('firebase-admin');

// Initialize with default credentials (uses GOOGLE_APPLICATION_CREDENTIALS or ADC)
if (!admin.apps.length) {
    admin.initializeApp();
}

const db = admin.firestore();
const BATCH_SIZE = 400; // Firestore limit is 500 per batch

// ─── Counters ─────────────────────────────────────────────────────
const stats = {
    usersProcessed: 0,
    transactionsMigrated: 0,
    transactionsSkipped: 0,
    splitsMigrated: 0,
    splitsSkipped: 0,
    groupTxMigrated: 0,
    groupTxSkipped: 0,
    recurringTxMigrated: 0,
    recurringTxSkipped: 0,
    minorModelsMigrated: 0,
    minorModelsSkipped: 0,
    errors: [],
};

// ─── Phase 1: Transactions ───────────────────────────────────────
async function migrateTransactions(userId, categoryLookup) {
    const txRef = db.collection('users').doc(userId).collection('transactions');
    const snapshot = await txRef.get();
    const docs = snapshot.docs;

    for (let i = 0; i < docs.length; i += BATCH_SIZE) {
        const batch = db.batch();
        let batchCount = 0;
        const slice = docs.slice(i, i + BATCH_SIZE);

        for (const doc of slice) {
            const data = doc.data();
            const hasSubtitle = data.subtitle !== undefined;
            const hasIcon = data.icon !== undefined;
            const hasColorHex = data.colorHex !== undefined;
            const hasCategoryId = data.categoryId !== undefined;

            // Already clean
            if (!hasSubtitle && !hasIcon && !hasColorHex) {
                stats.transactionsSkipped++;
                continue;
            }

            const updates = {};

            // Backfill categoryId from subtitle
            if (!hasCategoryId && typeof data.subtitle === 'string') {
                const key = data.subtitle.toLowerCase();
                if (categoryLookup[key]) {
                    updates.categoryId = categoryLookup[key];
                }
            }

            // Delete legacy fields
            if (hasSubtitle) updates.subtitle = admin.firestore.FieldValue.delete();
            if (hasIcon) updates.icon = admin.firestore.FieldValue.delete();
            if (hasColorHex) updates.colorHex = admin.firestore.FieldValue.delete();

            batch.update(doc.ref, updates);
            batchCount++;
        }

        if (batchCount > 0) {
            await batch.commit();
            stats.transactionsMigrated += batchCount;
        }
    }
}

// ─── Phase 2: Split Requests ─────────────────────────────────────
async function migrateSplitRequests(userId) {
    // Fetch splits where user is sender OR receiver
    const [fromSnap, toSnap] = await Promise.all([
        db.collection('split_requests').where('fromUid', '==', userId).get(),
        db.collection('split_requests').where('toUid', '==', userId).get(),
    ]);

    // Deduplicate
    const docMap = {};
    for (const doc of fromSnap.docs) docMap[doc.id] = doc;
    for (const doc of toSnap.docs) docMap[doc.id] = doc;
    const docs = Object.values(docMap);

    for (let i = 0; i < docs.length; i += BATCH_SIZE) {
        const batch = db.batch();
        let batchCount = 0;
        const slice = docs.slice(i, i + BATCH_SIZE);

        for (const doc of slice) {
            const data = doc.data();
            const hasFromName = data.fromName !== undefined;
            const hasToName = data.toName !== undefined;

            if (!hasFromName && !hasToName) {
                stats.splitsSkipped++;
                continue;
            }

            const updates = {};
            if (hasFromName) updates.fromName = admin.firestore.FieldValue.delete();
            if (hasToName) updates.toName = admin.firestore.FieldValue.delete();

            batch.update(doc.ref, updates);
            batchCount++;
        }

        if (batchCount > 0) {
            await batch.commit();
            stats.splitsMigrated += batchCount;
        }
    }
}

// ─── Phase 3: Group Transactions ─────────────────────────────────
async function migrateGroupTransactions(userId) {
    const groupsSnap = await db
        .collection('groups')
        .where('members', 'array-contains', userId)
        .get();

    for (const groupDoc of groupsSnap.docs) {
        const groupId = groupDoc.id;
        const txSnap = await db
            .collection('groups')
            .doc(groupId)
            .collection('transactions')
            .get();

        const docs = txSnap.docs;

        for (let i = 0; i < docs.length; i += BATCH_SIZE) {
            const batch = db.batch();
            let batchCount = 0;
            const slice = docs.slice(i, i + BATCH_SIZE);

            for (const doc of slice) {
                const data = doc.data();
                const hasPayerName = data.payerName !== undefined;
                const hasReceiverName = data.receiverName !== undefined;
                const hasCategory = data.category !== undefined;
                const hasIcon = data.icon !== undefined;
                const hasColorHex = data.colorHex !== undefined;

                if (!hasPayerName && !hasReceiverName && !hasCategory && !hasIcon && !hasColorHex) {
                    stats.groupTxSkipped++;
                    continue;
                }

                const updates = {};
                if (hasPayerName) updates.payerName = admin.firestore.FieldValue.delete();
                if (hasReceiverName) updates.receiverName = admin.firestore.FieldValue.delete();
                if (hasCategory) updates.category = admin.firestore.FieldValue.delete();
                if (hasIcon) updates.icon = admin.firestore.FieldValue.delete();
                if (hasColorHex) updates.colorHex = admin.firestore.FieldValue.delete();

                batch.update(doc.ref, updates);
                batchCount++;
            }

            if (batchCount > 0) {
                await batch.commit();
                stats.groupTxMigrated += batchCount;
                console.log(`  ✅ Group [${groupId}] batch: ${batchCount} docs`);
            }
        }
    }
}

// ─── Phase 4: Recurring Transactions ─────────────────────────────
async function migrateRecurringTransactions(userId, categoryLookup) {
    const rxRef = db.collection('users').doc(userId).collection('recurringTransactions');
    const snapshot = await rxRef.get();
    const docs = snapshot.docs;

    for (let i = 0; i < docs.length; i += BATCH_SIZE) {
        const batch = db.batch();
        let batchCount = 0;
        const slice = docs.slice(i, i + BATCH_SIZE);

        for (const doc of slice) {
            const data = doc.data();
            const hasIcon = data.icon !== undefined;
            const hasColorHex = data.colorHex !== undefined;
            const hasCategoryId = data.categoryId !== undefined;

            // Already clean
            if (!hasIcon && !hasColorHex && hasCategoryId) {
                stats.recurringTxSkipped++;
                continue;
            }

            const updates = {};

            // Backfill categoryId from name
            if (!hasCategoryId && typeof data.name === 'string') {
                const key = data.name.toLowerCase();
                if (categoryLookup[key]) {
                    updates.categoryId = categoryLookup[key];
                }
            }

            // Delete legacy fields
            if (hasIcon) updates.icon = admin.firestore.FieldValue.delete();
            if (hasColorHex) updates.colorHex = admin.firestore.FieldValue.delete();

            batch.update(doc.ref, updates);
            batchCount++;
        }

        if (batchCount > 0) {
            await batch.commit();
            stats.recurringTxMigrated += batchCount;
        }
    }
}

// ─── Phase 5: Minor Social Models ────────────────────────────────
async function migrateMinorModels(userId) {
    // 1. Friend Requests
    const [frFromSnap, frToSnap] = await Promise.all([
        db.collection('friend_requests').where('fromUid', '==', userId).get(),
        db.collection('friend_requests').where('toUid', '==', userId).get(),
    ]);

    const frDocMap = {};
    for (const doc of frFromSnap.docs) frDocMap[doc.id] = doc;
    for (const doc of frToSnap.docs) frDocMap[doc.id] = doc;
    const frDocs = Object.values(frDocMap);

    for (let i = 0; i < frDocs.length; i += BATCH_SIZE) {
        const batch = db.batch();
        let batchCount = 0;
        const slice = frDocs.slice(i, i + BATCH_SIZE);

        for (const doc of slice) {
            const data = doc.data();
            const hasFromName = data.fromName !== undefined;
            const hasFromUsername = data.fromUsername !== undefined;

            if (!hasFromName && !hasFromUsername) {
                stats.minorModelsSkipped++;
                continue;
            }

            const updates = {};
            if (hasFromName) updates.fromName = admin.firestore.FieldValue.delete();
            if (hasFromUsername) updates.fromUsername = admin.firestore.FieldValue.delete();

            batch.update(doc.ref, updates);
            batchCount++;
        }

        if (batchCount > 0) {
            await batch.commit();
            stats.minorModelsMigrated += batchCount;
        }
    }

    // 2. Group Invitations
    const [giFromSnap, giToSnap] = await Promise.all([
        db.collection('group_invitations').where('fromUid', '==', userId).get(),
        db.collection('group_invitations').where('toUid', '==', userId).get(),
    ]);

    const giDocMap = {};
    for (const doc of giFromSnap.docs) giDocMap[doc.id] = doc;
    for (const doc of giToSnap.docs) giDocMap[doc.id] = doc;
    const giDocs = Object.values(giDocMap);

    for (let i = 0; i < giDocs.length; i += BATCH_SIZE) {
        const batch = db.batch();
        let batchCount = 0;
        const slice = giDocs.slice(i, i + BATCH_SIZE);

        for (const doc of slice) {
            const data = doc.data();
            if (data.groupName === undefined) {
                stats.minorModelsSkipped++;
                continue;
            }

            batch.update(doc.ref, { groupName: admin.firestore.FieldValue.delete() });
            batchCount++;
        }

        if (batchCount > 0) {
            await batch.commit();
            stats.minorModelsMigrated += batchCount;
        }
    }

    // 3. Edit History on Transactions
    const txSnap = await db.collection('users').doc(userId).collection('transactions').get();
    for (let i = 0; i < txSnap.docs.length; i += BATCH_SIZE) {
        const batch = db.batch();
        let batchCount = 0;
        const slice = txSnap.docs.slice(i, i + BATCH_SIZE);

        for (const doc of slice) {
            const data = doc.data();
            const editHistory = data.editHistory;

            if (!Array.isArray(editHistory) || editHistory.length === 0) {
                stats.minorModelsSkipped++;
                continue;
            }

            let needsMigration = false;
            const cleanedHistory = editHistory.map(record => {
                if (record.editorName !== undefined) {
                    needsMigration = true;
                    const { editorName, ...rest } = record;
                    return rest;
                }
                return record;
            });

            if (!needsMigration) {
                stats.minorModelsSkipped++;
                continue;
            }

            batch.update(doc.ref, { editHistory: cleanedHistory });
            batchCount++;
        }

        if (batchCount > 0) {
            await batch.commit();
            stats.minorModelsMigrated += batchCount;
        }
    }

    // 4. Edit History on Group Transactions
    const groupsSnap = await db.collection('groups').where('members', 'array-contains', userId).get();
    for (const groupDoc of groupsSnap.docs) {
        const gTxSnap = await db.collection('groups').doc(groupDoc.id).collection('transactions').get();

        for (let i = 0; i < gTxSnap.docs.length; i += BATCH_SIZE) {
            const batch = db.batch();
            let batchCount = 0;
            const slice = gTxSnap.docs.slice(i, i + BATCH_SIZE);

            for (const doc of slice) {
                const data = doc.data();
                const editHistory = data.editHistory;

                if (!Array.isArray(editHistory) || editHistory.length === 0) {
                    stats.minorModelsSkipped++;
                    continue;
                }

                let needsMigration = false;
                const cleanedHistory = editHistory.map(record => {
                    if (record.editorName !== undefined) {
                        needsMigration = true;
                        const { editorName, ...rest } = record;
                        return rest;
                    }
                    return record;
                });

                if (!needsMigration) {
                    stats.minorModelsSkipped++;
                    continue;
                }

                batch.update(doc.ref, { editHistory: cleanedHistory });
                batchCount++;
            }

            if (batchCount > 0) {
                await batch.commit();
                stats.minorModelsMigrated += batchCount;
            }
        }
    }
}

// ─── Main ────────────────────────────────────────────────────────
async function main() {
    console.log('🚀 Starting server-side migration for ALL users...\n');

    // Get every user document
    const usersSnap = await db.collection('users').get();
    const totalUsers = usersSnap.size;
    console.log(`Found ${totalUsers} users.\n`);

    for (const userDoc of usersSnap.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();
        const displayName = userData.name || userData.displayName || userId;

        console.log(`\n── User: ${displayName} (${userId}) ──`);

        try {
            // Build this user's category lookup: name → id
            const budgetsSnap = await db
                .collection('users')
                .doc(userId)
                .collection('budgets')
                .get();

            const categoryLookup = {};
            for (const bDoc of budgetsSnap.docs) {
                const bData = bDoc.data();
                if (bData.category) {
                    categoryLookup[bData.category.toLowerCase()] = bDoc.id;
                }
            }

            console.log(`  📂 Category lookup built: ${Object.keys(categoryLookup).length} categories`);

            // Phase 1
            console.log('  📦 Phase 1: Transactions...');
            await migrateTransactions(userId, categoryLookup);

            // Phase 2
            console.log('  📦 Phase 2: Split Requests...');
            await migrateSplitRequests(userId);

            // Phase 3
            console.log('  📦 Phase 3: Group Transactions...');
            await migrateGroupTransactions(userId);

            // Phase 4
            console.log('  📦 Phase 4: Recurring Transactions...');
            await migrateRecurringTransactions(userId, categoryLookup);

            // Phase 5
            console.log('  📦 Phase 5: Minor Social Models...');
            await migrateMinorModels(userId);

            stats.usersProcessed++;
            console.log(`  ✅ User done (${stats.usersProcessed}/${totalUsers})`);
        } catch (err) {
            const msg = `❌ Error migrating user ${userId}: ${err.message}`;
            console.error(msg);
            stats.errors.push(msg);
        }
    }

    // ── Summary ──
    console.log('\n══════════════════════════════════════');
    console.log('       MIGRATION COMPLETE');
    console.log('══════════════════════════════════════');
    console.log(`Users processed:         ${stats.usersProcessed} / ${totalUsers}`);
    console.log(`Transactions migrated:   ${stats.transactionsMigrated}`);
    console.log(`Transactions skipped:    ${stats.transactionsSkipped}`);
    console.log(`Split Requests migrated: ${stats.splitsMigrated}`);
    console.log(`Split Requests skipped:  ${stats.splitsSkipped}`);
    console.log(`Group Tx migrated:       ${stats.groupTxMigrated}`);
    console.log(`Group Tx skipped:        ${stats.groupTxSkipped}`);
    console.log(`Recurring Tx migrated:   ${stats.recurringTxMigrated}`);
    console.log(`Recurring Tx skipped:    ${stats.recurringTxSkipped}`);
    console.log(`Minor Models migrated:   ${stats.minorModelsMigrated}`);
    console.log(`Minor Models skipped:    ${stats.minorModelsSkipped}`);
    console.log(`Errors:                  ${stats.errors.length}`);
    if (stats.errors.length > 0) {
        console.log('\nError details:');
        stats.errors.forEach((e) => console.log(`  ${e}`));
    }
    console.log('══════════════════════════════════════\n');
}

main().catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
});
