// Re-export all trigger functions from domain-specific modules
const friendRequests = require('./friendRequests');
const groupInvites = require('./groupInvites');
const splitRequests = require('./splitRequests');
const userProfile = require('./userProfile');
const groups = require('./groups');

// Friend Requests
exports.v2_onFriendRequestCreated = friendRequests.v2_onFriendRequestCreated;
exports.v2_onFriendRequestUpdated = friendRequests.v2_onFriendRequestUpdated;
exports.v2_onFriendDeleted = friendRequests.v2_onFriendDeleted;

// Group Invitations
exports.v2_onGroupInvitationCreated = groupInvites.v2_onGroupInvitationCreated;
exports.v2_onGroupInvitationUpdated = groupInvites.v2_onGroupInvitationUpdated;

// Split Requests
exports.v2_onSplitRequestCreated = splitRequests.v2_onSplitRequestCreated;
exports.v2_onSplitRequestUpdated = splitRequests.v2_onSplitRequestUpdated;
exports.v2_onSplitRequestDeleted = splitRequests.v2_onSplitRequestDeleted;

// User Profile
exports.v2_onUserUpdated = userProfile.v2_onUserUpdated;

// Groups (Gap #7: Merged v2_onGroupMemberAdded into v2_onGroupUpdated)
exports.v2_onGroupUpdated = groups.v2_onGroupUpdated;
exports.v2_onGroupDeleted = groups.v2_onGroupDeleted; // FIX 2.5: Subcollection cleanup
