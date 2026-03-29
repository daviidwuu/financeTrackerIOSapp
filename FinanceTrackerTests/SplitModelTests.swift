import Testing
import Foundation
@testable import FinanceTracker

// MARK: - Split Model & Status Transition Tests
//
// Tests the Split value type, its computed legacy accessors, and the
// status-transition rules baked into the Codable implementation.
// Also covers TransactionModel sign-normalisation which is critical for
// correct budget / balance calculations.

@Suite struct SplitModelTests {

    // MARK: - SplitStatus computed accessors

    @Test("isPaid is true only when splitStatus is .paid")
    func test_isPaid_paidStatus_returnsTrue() {
        let split = FirestoreModels.Split(name: "Alice", amount: 30.0, splitStatus: .paid)
        #expect(split.isPaid == true)
        #expect(split.isAccepted == true) // paid implies accepted
    }

    @Test("isAccepted is true for both .accepted and .paid")
    func test_isAccepted_acceptedAndPaid() {
        let accepted = FirestoreModels.Split(name: "Bob", amount: 20.0, splitStatus: .accepted)
        let paid     = FirestoreModels.Split(name: "Bob", amount: 20.0, splitStatus: .paid)
        let pending  = FirestoreModels.Split(name: "Bob", amount: 20.0, splitStatus: .pending)
        let declined = FirestoreModels.Split(name: "Bob", amount: 20.0, splitStatus: .declined)

        #expect(accepted.isAccepted == true)
        #expect(paid.isAccepted == true)
        #expect(pending.isAccepted == false)
        #expect(declined.isAccepted == false)
    }

    @Test("Setting isPaid = true transitions status to .paid")
    func test_setIsPaid_true_setsStatusPaid() {
        var split = FirestoreModels.Split(name: "Carol", amount: 15.0, splitStatus: .pending)
        split.isPaid = true
        #expect(split.splitStatus == .paid)
    }

    @Test("Setting isPaid = false on a paid split reverts to .pending")
    func test_setIsPaid_false_revertsFromPaid() {
        var split = FirestoreModels.Split(name: "Carol", amount: 15.0, splitStatus: .paid)
        split.isPaid = false
        #expect(split.splitStatus == .pending)
    }

    @Test("Setting isPaid = false on a non-paid split leaves status unchanged")
    func test_setIsPaid_false_nonPaid_unchanged() {
        var split = FirestoreModels.Split(name: "Dave", amount: 10.0, splitStatus: .accepted)
        split.isPaid = false
        // Should NOT revert accepted → pending when it wasn't paid
        #expect(split.splitStatus == .accepted)
    }

    @Test("Setting isAccepted = true on pending transitions to .accepted")
    func test_setIsAccepted_pending_movesToAccepted() {
        var split = FirestoreModels.Split(name: "Eve", amount: 25.0, splitStatus: .pending)
        split.isAccepted = true
        #expect(split.splitStatus == .accepted)
    }

    @Test("Setting isAccepted = true on already paid split leaves status as .paid")
    func test_setIsAccepted_alreadyPaid_unchanged() {
        var split = FirestoreModels.Split(name: "Eve", amount: 25.0, splitStatus: .paid)
        split.isAccepted = true
        // Should not downgrade paid → accepted
        #expect(split.splitStatus == .paid)
    }

    // MARK: - Legacy `status` string accessor

    @Test("status string accessor returns correct raw value for each case")
    func test_statusString_allCases() {
        let pending  = FirestoreModels.Split(name: "X", amount: 1, splitStatus: .pending)
        let accepted = FirestoreModels.Split(name: "X", amount: 1, splitStatus: .accepted)
        let paid     = FirestoreModels.Split(name: "X", amount: 1, splitStatus: .paid)
        let declined = FirestoreModels.Split(name: "X", amount: 1, splitStatus: .declined)

        #expect(pending.status  == "pending")
        #expect(accepted.status == "accepted")
        #expect(paid.status     == "paid")
        #expect(declined.status == "declined")
    }

    @Test("Setting status string updates splitStatus enum correctly")
    func test_setStatusString_updatesEnum() {
        var split = FirestoreModels.Split(name: "X", amount: 1, splitStatus: .pending)
        split.status = "accepted"
        #expect(split.splitStatus == .accepted)

        split.status = "paid"
        #expect(split.splitStatus == .paid)

        split.status = "declined"
        #expect(split.splitStatus == .declined)
    }

    @Test("Invalid status string leaves splitStatus unchanged")
    func test_setStatusString_invalid_unchanged() {
        var split = FirestoreModels.Split(name: "X", amount: 1, splitStatus: .pending)
        split.status = "totally_invalid_status"
        #expect(split.splitStatus == .pending)
    }

    // MARK: - Codable: legacy field migration

    @Test("Decoding legacy isPaid=true maps to splitStatus .paid")
    func test_decode_legacyIsPaidTrue_mapsToPaid() throws {
        let json = """
        {
          "id": "abc",
          "name": "Alice",
          "amount": 50.0,
          "isPaid": true,
          "isAccepted": false
        }
        """.data(using: .utf8)!

        let split = try JSONDecoder().decode(FirestoreModels.Split.self, from: json)
        #expect(split.splitStatus == .paid)
    }

    @Test("Decoding legacy isAccepted=true (not paid) maps to splitStatus .accepted")
    func test_decode_legacyIsAcceptedTrue_mapsToAccepted() throws {
        let json = """
        {
          "id": "abc",
          "name": "Bob",
          "amount": 20.0,
          "isPaid": false,
          "isAccepted": true
        }
        """.data(using: .utf8)!

        let split = try JSONDecoder().decode(FirestoreModels.Split.self, from: json)
        #expect(split.splitStatus == .accepted)
    }

    @Test("Decoding legacy status string field takes priority over isPaid/isAccepted booleans")
    func test_decode_legacyStatusField_takesOverBooleans() throws {
        // 'status' field present and valid → should use it
        let json = """
        {
          "id": "abc",
          "name": "Carol",
          "amount": 30.0,
          "status": "declined",
          "isPaid": true,
          "isAccepted": true
        }
        """.data(using: .utf8)!

        let split = try JSONDecoder().decode(FirestoreModels.Split.self, from: json)
        // splitStatus field is absent → fallback to legacy 'status' string
        #expect(split.splitStatus == .declined)
    }

    @Test("Decoding new splitStatus field takes priority over all legacy fields")
    func test_decode_newSplitStatusField_hasHighestPriority() throws {
        let json = """
        {
          "id": "abc",
          "name": "Dave",
          "amount": 10.0,
          "splitStatus": "paid",
          "status": "pending",
          "isPaid": false,
          "isAccepted": false
        }
        """.data(using: .utf8)!

        let split = try JSONDecoder().decode(FirestoreModels.Split.self, from: json)
        #expect(split.splitStatus == .paid)
    }

    @Test("Decoding with no status fields defaults to .pending")
    func test_decode_noStatusFields_defaultsPending() throws {
        let json = """
        {
          "name": "Eve",
          "amount": 5.0
        }
        """.data(using: .utf8)!

        let split = try JSONDecoder().decode(FirestoreModels.Split.self, from: json)
        #expect(split.splitStatus == .pending)
    }

    // MARK: - TransactionModel sign normalisation

    @Test("Expense amount is always stored as negative")
    func test_transactionModel_expenseAlwaysNegative() {
        let t1 = FirestoreModels.TransactionModel(userId: "u1", title: "Coffee", amount: 5.0, date: Date(), type: "expense", createdAt: Date())
        #expect(t1.amount < 0)
        #expect(t1.amount == -5.0)
    }

    @Test("Expense created with already-negative amount is unchanged")
    func test_transactionModel_expenseNegativeInput_preserved() {
        let t = FirestoreModels.TransactionModel(userId: "u1", title: "Bus", amount: -2.50, date: Date(), type: "expense", createdAt: Date())
        #expect(t.amount == -2.50)
    }

    @Test("Income amount is always stored as positive")
    func test_transactionModel_incomeAlwaysPositive() {
        let t1 = FirestoreModels.TransactionModel(userId: "u1", title: "Salary", amount: -3000.0, date: Date(), type: "income", createdAt: Date())
        #expect(t1.amount > 0)
        #expect(t1.amount == 3000.0)
    }

    @Test("normalizeAmount: expense with positive input returns negative")
    func test_normalizeAmount_expensePositive() {
        let result = FirestoreModels.TransactionModel.normalizeAmount(100.0, type: "expense")
        #expect(result == -100.0)
    }

    @Test("normalizeAmount: income with negative input returns positive")
    func test_normalizeAmount_incomeNegative() {
        let result = FirestoreModels.TransactionModel.normalizeAmount(-500.0, type: "income")
        #expect(result == 500.0)
    }

    @Test("normalizeAmount: unknown type leaves amount unchanged")
    func test_normalizeAmount_unknownType_unchanged() {
        let result = FirestoreModels.TransactionModel.normalizeAmount(42.0, type: "transfer")
        #expect(result == 42.0)
    }
}
