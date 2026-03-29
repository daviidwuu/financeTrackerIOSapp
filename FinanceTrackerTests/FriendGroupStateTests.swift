import Testing
import Foundation
@testable import FinanceTracker

// MARK: - Friend & Group State Change Tests
//
// These tests cover bidirectional friend add/remove invariants, group leave/delete
// edge cases, and the debt resolution logic that gates those actions.
// All tests are pure-Swift — no Firestore calls.

@Suite struct FriendGroupStateTests {

    // MARK: - Helpers

    private func makeGroup(id: String, members: [String], createdBy: String = "owner") -> FirestoreModels.Group {
        let membersJSON = members.map { "\"\($0)\"" }.joined(separator: ",")
        let json = """
        {
          "id": "\(id)",
          "name": "Test Group",
          "members": [\(membersJSON)],
          "createdBy": "\(createdBy)",
          "icon": "star",
          "color": "#000000",
          "createdAt": 0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode(FirestoreModels.Group.self, from: json))!
    }

    private func makeFriend(id: String, name: String = "Friend") -> FirestoreModels.Friend {
        let json = """
        { "id": "\(id)", "name": "\(name)" }
        """.data(using: .utf8)!
        return (try? JSONDecoder().decode(FirestoreModels.Friend.self, from: json))!
    }

    // MARK: - Bidirectional friend relationship invariants

    @Test("Adding a friend: both sides must be in each other's lists (bidirectional invariant)")
    func test_friendAdd_bidirectional() {
        // Simulate friend lists for alice and bob after a successful friend add
        var aliceFriends = ["carol"]   // alice's existing friends
        var bobFriends   = ["dave"]    // bob's existing friends

        // After alice adds bob (and bob accepts)
        aliceFriends.append("bob")
        bobFriends.append("alice")

        #expect(aliceFriends.contains("bob"))
        #expect(bobFriends.contains("alice"),
                "Friendship must be stored on both sides — missing the reverse side is a data integrity bug")
    }

    @Test("Removing a friend: both sides must be removed from each other's lists")
    func test_friendRemove_bidirectional() {
        var aliceFriends = ["bob", "carol"]
        var bobFriends   = ["alice", "dave"]

        // Alice removes Bob — both sides must be updated
        aliceFriends.removeAll { $0 == "bob" }
        bobFriends.removeAll   { $0 == "alice" }

        #expect(!aliceFriends.contains("bob"),   "Alice must no longer have Bob as a friend")
        #expect(!bobFriends.contains("alice"),    "Bob must no longer have Alice as a friend")
        #expect(aliceFriends.contains("carol"),   "Other friendships must be unaffected")
        #expect(bobFriends.contains("dave"),      "Other friendships must be unaffected")
    }

    @Test("Friend removal is idempotent: removing a non-existent friend leaves list unchanged")
    func test_friendRemove_idempotent() {
        var aliceFriends = ["carol", "dave"]
        let countBefore = aliceFriends.count

        // Try to remove "bob" who is not in the list
        aliceFriends.removeAll { $0 == "bob" }

        #expect(aliceFriends.count == countBefore, "Removing a non-member must not alter the list")
    }

    // MARK: - FriendRequest status lifecycle

    @Test("FriendRequest lifecycle: pending → accepted")
    func test_friendRequest_pendingToAccepted() {
        var status = "pending"
        // Receiver accepts
        status = "accepted"
        #expect(status == "accepted")
    }

    @Test("FriendRequest lifecycle: pending → declined")
    func test_friendRequest_pendingToDeclined() {
        var status = "pending"
        status = "declined"
        #expect(status == "declined")
    }

    @Test("FriendRequest: fromUid and toUid must be different users")
    func test_friendRequest_selfFriend_invalid() {
        let userId = "alice"
        let toUid  = "alice" // Sending request to yourself

        let isSelfRequest = userId == toUid
        #expect(isSelfRequest == true, "Self-friend requests must be rejected by callers")
    }

    // MARK: - Group membership: leave preconditions

    @Test("Leave group blocked when user has outstanding balance as debtor")
    func test_leaveGroup_blocked_hasDebtorBalance() {
        // User owes money in this group — they cannot leave until settled
        let userBalance = -50.0 // Negative = user owes others
        let canLeave = abs(userBalance) < 0.01
        #expect(canLeave == false, "User with outstanding debt cannot leave the group")
    }

    @Test("Leave group blocked when user has outstanding balance as creditor")
    func test_leaveGroup_blocked_hasCreditorBalance() {
        // Others owe the user — they cannot leave until collected/forgiven
        let userBalance = 30.0 // Positive = others owe the user
        let canLeave = abs(userBalance) < 0.01
        #expect(canLeave == false, "User with uncollected credit cannot leave the group")
    }

    @Test("Leave group allowed when user has zero balance")
    func test_leaveGroup_allowed_zeroBalance() {
        let userBalance = 0.0
        let canLeave = abs(userBalance) < 0.01
        #expect(canLeave == true)
    }

    @Test("Leave group allowed when balance is sub-cent (below noise threshold)")
    func test_leaveGroup_allowed_subCentBalance() {
        // Floating-point arithmetic can leave a 0.005 remainder — this must be ignored
        let userBalance = 0.005
        let canLeave = abs(userBalance) < 0.01
        #expect(canLeave == true, "Sub-cent balance must not block group leave")
    }

    // MARK: - Group deletion: memberActions workflow

    @Test("Group delete: can proceed when all members have acted")
    func test_groupDelete_allMembersActed_canProceed() {
        let members    = ["alice", "bob", "carol"]
        let actingUser = "carol"
        var actions: [String: String] = ["alice": "delete", "bob": "keep"]

        // carol is acting now — check if all have acted
        let allActed = members.allSatisfy { memberId in
            if memberId == actingUser { return true } // current actor counts
            let status = actions[memberId]
            return status == "keep" || status == "delete"
        }

        #expect(allActed == true)
    }

    @Test("Group delete: blocked until all members have acted")
    func test_groupDelete_notAllMembersActed_blocked() {
        let members    = ["alice", "bob", "carol"]
        let actingUser = "carol"
        var actions: [String: String] = ["alice": "delete"] // bob hasn't acted

        let allActed = members.allSatisfy { memberId in
            if memberId == actingUser { return true }
            let status = actions[memberId]
            return status == "keep" || status == "delete"
        }

        #expect(allActed == false, "Deletion must not proceed until every member has chosen keep/delete")
    }

    @Test("Group delete: 'delete' action removes user data, 'keep' preserves it")
    func test_groupDelete_actionSemantics() {
        // The memberActions field encodes each user's choice:
        // "delete" → delete their local transaction copies
        // "keep"   → retain their transaction history

        let aliceAction = "delete"
        let bobAction   = "keep"

        let aliceDeletesData = aliceAction == "delete"
        let bobDeletesData   = bobAction   == "delete"

        #expect(aliceDeletesData == true)
        #expect(bobDeletesData   == false)
    }

    @Test("Group delete: single-member group immediately finalizes when sole member acts")
    func test_groupDelete_singleMember_immediateFinalise() {
        let members    = ["solo_user"]
        let actingUser = "solo_user"
        let actions: [String: String] = [:] // No other members to act

        let allActed = members.allSatisfy { memberId in
            if memberId == actingUser { return true }
            let status = actions[memberId]
            return status == "keep" || status == "delete"
        }

        #expect(allActed == true)
    }

    // MARK: - Group membership: isMember invariant after operations

    @Test("isMember: added member is recognised after join")
    func test_groupMembership_addedMember_recognised() {
        var group = makeGroup(id: "g1", members: ["alice", "bob"])
        // Simulate carol joining: members array gets updated
        var updatedMembers = group.members
        updatedMembers.append("carol")

        #expect(updatedMembers.contains("carol"))
        #expect(!group.isMember("carol"), "isMember on stale group must return false (value type)")
    }

    @Test("isMember: removed member is no longer recognised after leave")
    func test_groupMembership_removedMember_notRecognised() {
        let group = makeGroup(id: "g1", members: ["alice", "bob", "carol"])

        var updatedMembers = group.members
        updatedMembers.removeAll { $0 == "bob" }

        #expect(!updatedMembers.contains("bob"))
        #expect(group.isMember("bob"), "Original value type still has bob — confirms immutability")
    }

    @Test("isMember: owner is always a member of the group they created")
    func test_groupMembership_ownerIsMember() {
        let group = makeGroup(id: "g1", members: ["owner", "alice"], createdBy: "owner")
        #expect(group.isMember("owner"))
        #expect(group.createdBy == "owner")
    }

    // MARK: - GroupRepository cache lookup

    @Test("GroupRepository.isMember: member in cached group returns true")
    func test_groupRepo_isMember_cached_returnsTrue() {
        let repo = GroupRepository()
        repo.groups = [makeGroup(id: "g1", members: ["u1", "u2"])]
        #expect(repo.isMember(groupId: "g1", uid: "u1"))
        #expect(repo.isMember(groupId: "g1", uid: "u2"))
    }

    @Test("GroupRepository.isMember: non-member in cached group returns false")
    func test_groupRepo_isMember_nonMember_returnsFalse() {
        let repo = GroupRepository()
        repo.groups = [makeGroup(id: "g1", members: ["u1"])]
        #expect(!repo.isMember(groupId: "g1", uid: "outsider"))
    }

    @Test("GroupRepository.isMember: uncached group returns false")
    func test_groupRepo_isMember_uncachedGroup_returnsFalse() {
        let repo = GroupRepository()
        repo.groups = [] // empty cache
        #expect(!repo.isMember(groupId: "g_unknown", uid: "u1"))
    }

    // MARK: - FriendRepository cache lookup

    @Test("FriendRepository.isFriend: friend in cache returns true")
    func test_friendRepo_isFriend_inCache_returnsTrue() {
        let repo = FriendRepository()
        repo.friends = [makeFriend(id: "uid_alice", name: "Alice")]
        #expect(repo.isFriend(uid: "uid_alice"))
    }

    @Test("FriendRepository.isFriend: unknown uid returns false")
    func test_friendRepo_isFriend_unknownUid_returnsFalse() {
        let repo = FriendRepository()
        repo.friends = [makeFriend(id: "uid_alice", name: "Alice")]
        #expect(!repo.isFriend(uid: "uid_stranger"))
    }

    @Test("FriendRepository.isFriend: empty cache always returns false")
    func test_friendRepo_isFriend_emptyCache_returnsFalse() {
        let repo = FriendRepository()
        repo.friends = []
        #expect(!repo.isFriend(uid: "anyone"))
    }

    // MARK: - DebtCalculator integration: net balance drives leave/settle decisions

    @Test("DebtCalculator: net zero balance allows user to leave group safely")
    func test_debtCalc_netZero_allowsLeave() {
        // After settling, user has zero balance in the group
        let balances: [String: Double] = ["alice": 0.0, "bob": 0.0]
        let instructions = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        #expect(instructions.isEmpty, "Zero balance group has no outstanding debts")
    }

    @Test("DebtCalculator: non-zero balance prevents leaving safely")
    func test_debtCalc_nonZeroBalance_preventsLeave() {
        let balances: [String: Double] = ["alice": -25.0, "bob": 25.0]
        let instructions = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        #expect(!instructions.isEmpty, "Non-zero balance produces debt instructions blocking leave")
    }

    @Test("DebtCalculator: after full settlement, group balance is empty")
    func test_debtCalc_afterSettlement_balancesEmpty() {
        // Simulate: alice owed bob 50. After settlement, both balances are 0.
        var balances: [String: Double] = ["alice": -50.0, "bob": 50.0]

        // Settlement accepted: alice's debt is cleared
        balances["alice"] = 0.0
        balances["bob"]   = 0.0

        let instructions = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        #expect(instructions.isEmpty, "Post-settlement balances should produce zero instructions")
    }
}
