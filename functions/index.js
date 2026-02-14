const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

// CRITICAL: Use Firebase Admin SDK service account
setGlobalOptions({
  serviceAccount: 'firebase-adminsdk-fbsvc@financetracker-c628c.iam.gserviceaccount.com'
});

admin.initializeApp();

// Export modules
exports.http = require('./src/http');
exports.scheduled = require('./src/scheduled');
exports.triggers = require('./src/triggers');

// Re-export individual functions for cleaner deployment names if needed
// Or let Firebase deploy them as groups (e.g., http.addTransaction)
// For backward compatibility, we can re-export them directly:
const http = require('./src/http');
const scheduled = require('./src/scheduled');
const triggers = require('./src/triggers');

exports.addTransaction = http.addTransaction;
exports.processRecurringTransactions = scheduled.processRecurringTransactions;

// Triggers
exports.v2_onFriendRequestCreated = triggers.v2_onFriendRequestCreated;
exports.v2_onFriendRequestUpdated = triggers.v2_onFriendRequestUpdated;
exports.v2_onGroupInvitationCreated = triggers.v2_onGroupInvitationCreated;
exports.v2_onGroupInvitationUpdated = triggers.v2_onGroupInvitationUpdated;
exports.v2_onSplitRequestCreated = triggers.v2_onSplitRequestCreated;
exports.v2_onSplitRequestUpdated = triggers.v2_onSplitRequestUpdated;
exports.v2_onFriendDeleted = triggers.v2_onFriendDeleted;
exports.v2_onUserUpdated = triggers.v2_onUserUpdated;

// Legacy Triggers
exports.onSplitRequestCreatedLegacy = triggers.onSplitRequestCreatedLegacy;
exports.onSplitRequestUpdatedLegacy = triggers.onSplitRequestUpdatedLegacy;
exports.onTransactionUpdated = triggers.onTransactionUpdated;
exports.onTransactionDeleted = triggers.onTransactionDeleted;
