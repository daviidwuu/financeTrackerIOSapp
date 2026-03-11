const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

// CRITICAL: Use Firebase Admin SDK service account
setGlobalOptions({
  serviceAccount: 'firebase-adminsdk-fbsvc@financetracker-c628c.iam.gserviceaccount.com'
});

admin.initializeApp();

// Import modules
const http = require('./src/http');
const scheduled = require('./src/scheduled');
const triggers = require('./src/triggers');

// HTTP Functions
exports.addTransaction = http.addTransaction;
exports.revenueCatWebhook = http.revenueCatWebhook;

// Scheduled Functions
exports.processRecurringTransactions = scheduled.processRecurringTransactions;
exports.cleanupStaleRequests = scheduled.cleanupStaleRequests;

// Triggers — Friend Requests
exports.v2_onFriendRequestCreated = triggers.v2_onFriendRequestCreated;
exports.v2_onFriendRequestUpdated = triggers.v2_onFriendRequestUpdated;
exports.v2_onFriendDeleted = triggers.v2_onFriendDeleted;

// Triggers — Group Invitations
exports.v2_onGroupInvitationCreated = triggers.v2_onGroupInvitationCreated;
exports.v2_onGroupInvitationUpdated = triggers.v2_onGroupInvitationUpdated;

// Triggers — Split Requests
exports.v2_onSplitRequestCreated = triggers.v2_onSplitRequestCreated;
exports.v2_onSplitRequestUpdated = triggers.v2_onSplitRequestUpdated;
exports.v2_onSplitRequestDeleted = triggers.v2_onSplitRequestDeleted;

// Triggers — User Profile
exports.v2_onUserUpdated = triggers.v2_onUserUpdated;

// Triggers — Groups (Gap #7: Merged into single trigger)
exports.v2_onGroupUpdated = triggers.v2_onGroupUpdated;
exports.v2_onGroupDeleted = triggers.v2_onGroupDeleted; // FIX 2.5: Subcollection cleanup

// Triggers — Budget Aggregation (Phase 3: Server-side spent calculation)
exports.v2_onTransactionWritten = triggers.v2_onTransactionWritten;
