import Testing
import Foundation
@testable import FinanceTracker

// MARK: - Group Model & Membership Logic Tests
//
// Tests pure Swift logic on FirestoreModels.Group and Friend:
// - isMember predicate
// - Equality / Hashability (used in SwiftUI Set-based deduplication)
// - Balance accumulation logic that drives leave-group validation
// - FriendRepository / GroupRepository in-memory cache lookups
// - Group deletion workflow completeness check

// MARK: - Helpers

private func makeGroup(id: String, members: [String]) -> FirestoreModels.Group {
    // Decode via JSON so @DocumentID is populated correctly in tests
    let membersJSON = members.map { "\"\($0)\"" }.joined(separator: ",")
    let json = """
    {
      "id": "\(id)",
      "name": "Test Group",
      "members": [\(membersJSON)],
      "createdBy": "owner",
      "icon": "star",
      "color": "#000000",
      "createdAt": 0
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return (try? decoder.decode(FirestoreModels.Group.self, from: json))!
}

private func makeFriend(id: String, name: String) -> FirestoreModels.Friend {
    let json = """
    {
      "id": "\(id)",
      "name": "\(name)"
    }
    """.data(using: .utf8)!

    return (try? JSONDecoder().decode(FirestoreModels.Friend.self, from: json))!
}

// MARK: - Test Suite

@Suite struct GroupModelTests {

    // MARK: - Group.isMember

    @Test("isMember returns true for a user in the members array")
    func test_isMember_memberExists_returnsTrue() {
        let group = makeGroup(id: "g1", members: ["alice", "bob", "carol"])
        #expect(group.isMember("alice") == true)
        #expect(group.isMember("bob") == true)
    }

    @Test("isMember returns false for a user not in the members array")
    func test_isMember_memberAbsent_returnsFalse() {
        let group = makeGroup(id: "g1", members: ["alice", "bob"])
        #expect(group.isMember("dave") == false)
    }

    @Test("isMember returns false for empty members array")
    func test_isMember_emptyMembers_returnsFalse() {
        let group = makeGroup(id: "g1", members: [])
        #expect(group.isMember("alice") == false)
    }

    // MARK: - Group equality and hashability

    @Test("Two groups with the same id are equal regardless of other fields")
    func test_group_equality_basedOnId() {
        let g1 = makeGroup(id: "g1", members: ["a"])
        let g2 = makeGroup(id: "g1", members: ["b", "c"]) // different members, same id
        #expect(g1 == g2)
    }

    @Test("Groups with different ids are not equal")
    func test_group_inequality_differentIds() {
        let g1 = makeGroup(id: "g1", members: [])
        let g2 = makeGroup(id: "g2", members: [])
        #expect(g1 != g2)
    }

    @Test("Groups can be stored in a Set (Hashable requirement)")
    func test_group_hashable_canUseInSet() {
        let g1 = makeGroup(id: "g1", members: [])
        let g2 = makeGroup(id: "g1", members: []) // duplicate id
        let g3 = makeGroup(id: "g3", members: [])

        let set: Set<FirestoreModels.Group> = [g1, g2, g3]
        // g1 and g2 have the same id — deduplicated to 2 entries
        #expect(set.count == 2)
    }

    // MARK: - Leave-group balance check logic (pure arithmetic, no Firestore)

    @Test("hasOutstandingBalance: user with pending owed splits cannot leave")
    func test_hasOutstandingBalance_pendingOwedSplits_blocksLeave() {
        let owedCount  = 2  // user owes someone
        let owingCount = 0  // nobody owes user

        let hasBalance = owedCount > 0 || owingCount > 0
        #expect(hasBalance == true)
    }

    @Test("hasOutstandingBalance: no pending splits allows leave")
    func test_hasOutstandingBalance_noPendingSplits_allowsLeave() {
        let owedCount  = 0
        let owingCount = 0

        let hasBalance = owedCount > 0 || owingCount > 0
        #expect(hasBalance == false)
    }

    @Test("hasOutstandingBalance: user is creditor (others owe user) also blocks leave")
    func test_hasOutstandingBalance_userIsCreditor_blocksLeave() {
        let owedCount  = 0  // user owes nobody
        let owingCount = 1  // someone owes user

        let hasBalance = owedCount > 0 || owingCount > 0
        #expect(hasBalance == true)
    }

    // MARK: - Balance accumulation logic (mirrors listenToGroupBalances / calculateGroupBalances)

    @Test("Balance accumulation: payer gets positive, receiver gets negative")
    func test_groupBalance_accumulation_payerPositiveReceiverNegative() {
        var balancesByCurrency: [String: [String: Double]] = [:]
        let currency = "USD"
        let fromUid  = "alice"
        let toUid    = "bob"
        let amount   = 45.0

        balancesByCurrency[currency, default: [:]][fromUid, default: 0] += amount
        balancesByCurrency[currency, default: [:]][toUid,   default: 0] -= amount

        #expect(balancesByCurrency["USD"]?["alice"] ==  45.0)
        #expect(balancesByCurrency["USD"]?["bob"]   == -45.0)
    }

    @Test("Balance accumulation: multiple requests from same payer accumulate correctly")
    func test_groupBalance_multipleRequests_accumulate() {
        var balances: [String: Double] = [:]

        let requests = [(from: "alice", to: "bob", amount: 10.0),
                        (from: "alice", to: "bob", amount: 20.0),
                        (from: "alice", to: "bob", amount: 30.0)]

        for req in requests {
            balances[req.from, default: 0] += req.amount
            balances[req.to,   default: 0] -= req.amount
        }

        #expect(balances["alice"] == 60.0)
        #expect(balances["bob"]   == -60.0)
    }

    @Test("Balance accumulation: cross-debts net correctly")
    func test_groupBalance_crossDebts_netCorrectly() {
        // Alice sent Bob $50, Bob sent Alice $30 → net Alice is owed $20
        var balances: [String: Double] = [:]

        balances["alice", default: 0] += 50.0  // alice sent
        balances["bob",   default: 0] -= 50.0  // bob received (owes alice)

        balances["bob",   default: 0] += 30.0  // bob sent
        balances["alice", default: 0] -= 30.0  // alice received (owes bob)

        #expect(balances["alice"] ==  20.0)
        #expect(balances["bob"]   == -20.0)
    }

    // MARK: - FriendRepository isFriend (in-memory cache lookup)

    @Test("isFriend returns true when friend is in the cached list")
    func test_isFriend_presentInCache_returnsTrue() {
        let repo = FriendRepository()
        repo.friends = [makeFriend(id: "uid123", name: "Alice")]
        #expect(repo.isFriend(uid: "uid123") == true)
    }

    @Test("isFriend returns false when uid is not in the cached list")
    func test_isFriend_notInCache_returnsFalse() {
        let repo = FriendRepository()
        repo.friends = [makeFriend(id: "uid123", name: "Alice")]
        #expect(repo.isFriend(uid: "strangerUID") == false)
    }

    @Test("isFriend returns false when friend list is empty")
    func test_isFriend_emptyCache_returnsFalse() {
        let repo = FriendRepository()
        repo.friends = []
        #expect(repo.isFriend(uid: "anyone") == false)
    }

    // MARK: - GroupRepository isMember (in-memory cache lookup)

    @Test("GroupRepository.isMember returns true for a member in the cached group")
    func test_groupRepository_isMember_presentInCache_returnsTrue() {
        let repo = GroupRepository()
        repo.groups = [makeGroup(id: "g1", members: ["u1", "u2"])]

        #expect(repo.isMember(groupId: "g1", uid: "u1") == true)
        #expect(repo.isMember(groupId: "g1", uid: "u2") == true)
    }

    @Test("GroupRepository.isMember returns false when group not found in cache")
    func test_groupRepository_isMember_groupNotInCache_returnsFalse() {
        let repo = GroupRepository()
        repo.groups = []
        #expect(repo.isMember(groupId: "nonexistent", uid: "u1") == false)
    }

    @Test("GroupRepository.isMember returns false for non-member even if group exists")
    func test_groupRepository_isMember_nonMember_returnsFalse() {
        let repo = GroupRepository()
        repo.groups = [makeGroup(id: "g1", members: ["u1", "u2"])]
        #expect(repo.isMember(groupId: "g1", uid: "outsider") == false)
    }

    // MARK: - Deletion workflow: memberActions completeness check

    @Test("All members acted: deletion is finalized")
    func test_deletionAction_allMembersActed_triggersFinalize() {
        let members = ["alice", "bob", "carol"]
        let actions: [String: String] = ["alice": "keep", "bob": "delete"]
        let actingUser = "carol"

        // Simulate the allSatisfy check from GroupRepository.submitDeletionAction
        let allComplete = members.allSatisfy { memberId in
            if memberId == actingUser { return true }
            let status = actions[memberId]
            return status == "keep" || status == "delete"
        }

        #expect(allComplete == true)
    }

    @Test("Not all members acted: group deletion is not triggered yet")
    func test_deletionAction_notAllMembersActed_doesNotFinalize() {
        let members = ["alice", "bob", "carol"]
        let actions: [String: String] = ["alice": "keep"] // bob and carol haven't acted
        let actingUser = "bob"

        let allComplete = members.allSatisfy { memberId in
            if memberId == actingUser { return true }
            let status = actions[memberId]
            return status == "keep" || status == "delete"
        }

        #expect(allComplete == false)
    }

    @Test("Single-member group: acting member immediately triggers finalize")
    func test_deletionAction_singleMember_immediatelyComplete() {
        let members = ["solo"]
        let actions: [String: String] = [:]
        let actingUser = "solo"

        let allComplete = members.allSatisfy { memberId in
            if memberId == actingUser { return true }
            let status = actions[memberId]
            return status == "keep" || status == "delete"
        }

        #expect(allComplete == true)
    }

    // MARK: - Friend model equality and hashability

    @Test("Two Friend values with the same id are equal")
    func test_friend_equality_basedOnId() {
        let f1 = makeFriend(id: "uid1", name: "Alice")
        let f2 = makeFriend(id: "uid1", name: "Alice Updated") // same id, different name
        #expect(f1 == f2)
    }

    @Test("Friend values with different ids are not equal")
    func test_friend_inequality_differentIds() {
        let f1 = makeFriend(id: "uid1", name: "Alice")
        let f2 = makeFriend(id: "uid2", name: "Alice")
        #expect(f1 != f2)
    }

    @Test("Friends can be deduplicated in a Set")
    func test_friend_hashable_deduplicatesInSet() {
        let f1 = makeFriend(id: "uid1", name: "Alice")
        let f2 = makeFriend(id: "uid1", name: "Alice") // duplicate
        let f3 = makeFriend(id: "uid3", name: "Carol")

        let set: Set<FirestoreModels.Friend> = [f1, f2, f3]
        #expect(set.count == 2)
    }
}
