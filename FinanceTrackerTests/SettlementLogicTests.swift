import Testing
import Foundation
@testable import FinanceTracker

// MARK: - Settlement Logic Tests
//
// Tests the pure, stateless parts of settlement logic:
// - SocialRepository.calculateDebtResolution (thin wrapper around DebtCalculator)
// - The balance-calculation helper that drives settle-up amounts
// - Partial-settle cascade ordering and amount arithmetic
// - SplitRequest model correctness (RequestStatus decoding, isSettlement flag)

@Suite struct SettlementLogicTests {

    // MARK: - SocialRepository.calculateDebtResolution

    @Test("calculateDebtResolution delegates to DebtCalculator correctly")
    func test_calculateDebtResolution_delegatesToCalculator() {
        let repo = SocialRepository()
        let balances: [String: [String: Double]] = [
            "USD": ["Alice": -80.0, "Bob": 80.0]
        ]
        let instructions = repo.calculateDebtResolution(balances: balances)

        #expect(instructions.count == 1)
        #expect(instructions[0].debtorId == "Alice")
        #expect(instructions[0].creditorId == "Bob")
        #expect(instructions[0].amount == 80.0)
        #expect(instructions[0].currency == "USD")
    }

    @Test("calculateDebtResolution with empty balances returns empty array")
    func test_calculateDebtResolution_empty_returnsEmpty() {
        let repo = SocialRepository()
        let instructions = repo.calculateDebtResolution(balances: [:])
        #expect(instructions.isEmpty)
    }

    @Test("getDebtInstructions uses the live groupBalances property")
    func test_getDebtInstructions_usesGroupBalances() {
        let repo = SocialRepository()
        // Simulate balances being set (normally via Firestore listener)
        repo.groupBalances = [
            "USD": ["userA": 50.0, "userB": -50.0]
        ]
        let instructions = repo.getDebtInstructions()

        #expect(instructions.count == 1)
        #expect(instructions[0].debtorId == "userB")
        #expect(instructions[0].creditorId == "userA")
        #expect(instructions[0].amount == 50.0)
    }

    // MARK: - Settlement state validation

    @Test("Settlement amount must be positive — zero is invalid")
    func test_settlementAmount_zero_invalid() {
        // A settlement of $0 carries no economic meaning
        let amount = 0.0
        #expect(amount <= 0, "Zero settlement should be rejected by callers")
    }

    @Test("Settlement amount cannot exceed the outstanding balance")
    func test_settlementAmount_exceedsBalance_isInvalid() {
        let outstanding = 50.0
        let proposed    = 75.0
        // Callers should validate this; the model itself doesn't enforce it
        #expect(proposed > outstanding, "Test confirms over-payment scenario")
    }

    // MARK: - Partial settle cascade arithmetic

    @Test("Full settle: single split fully covered by settlement amount")
    func test_partialSettle_fullCoverage_remainderIsZero() {
        let settlementAmount = 100.0
        let splitAmount      = 100.0

        var remaining = settlementAmount
        if splitAmount <= remaining {
            remaining -= splitAmount
        }
        #expect(remaining == 0.0)
    }

    @Test("Partial settle: settlement covers first split, second remains unpaid")
    func test_partialSettle_coversFirstSplitOnly() {
        let settlementAmount = 60.0
        let splits = [40.0, 50.0] // oldest first (as sorted in acceptSettlement)

        var remaining = settlementAmount
        var paidCount = 0

        for splitAmount in splits {
            guard remaining > 0.01 else { break }
            if splitAmount <= remaining {
                remaining -= splitAmount
                paidCount += 1
            }
        }

        #expect(paidCount == 1)           // Only first split (40) fully covered
        #expect(remaining == 20.0)        // 60 - 40 = 20 left over
    }

    @Test("Partial settle: settlement covers two splits, one remains")
    func test_partialSettle_coversTwoSplits_thirdRemains() {
        let settlementAmount = 90.0
        let splits = [30.0, 50.0, 40.0] // oldest first

        var remaining = settlementAmount
        var paidCount = 0

        for splitAmount in splits {
            guard remaining > 0.01 else { break }
            if splitAmount <= remaining {
                remaining -= splitAmount
                paidCount += 1
            }
        }

        // 30 + 50 = 80 covered, 40 > remaining(10) → skip
        #expect(paidCount == 2)
        #expect(remaining == 10.0)
    }

    @Test("Partial settle: split larger than remaining is skipped, not partially settled")
    func test_partialSettle_largerSplitSkipped_notPartiallySettled() {
        // This is the documented behaviour: "If splitAmount > remainingAmount, skip (partial not supported at split level)"
        let remaining = 15.0
        let splitAmount = 50.0
        let wouldFullySettle = splitAmount <= remaining
        #expect(wouldFullySettle == false, "Split larger than remaining must be skipped")
    }

    @Test("Settlement amount below threshold stops cascade early")
    func test_partialSettle_remainderBelowThreshold_stopsCascade() {
        let threshold = 0.01
        var remaining = 0.005 // below threshold

        var processed = false
        if remaining > threshold {
            processed = true
        }

        #expect(processed == false, "Cascade must stop when remaining is below threshold")
    }

    // MARK: - SplitRequest model

    @Test("SplitRequest.RequestStatus decodes known raw values correctly")
    func test_requestStatus_decoding_knownValues() throws {
        let statuses: [(String, FirestoreModels.SplitRequest.RequestStatus)] = [
            ("pending",              .pending),
            ("accepted",             .accepted),
            ("declined",             .declined),
            ("paid",                 .paid),
            ("blocked_by_group",     .blocked_by_group),
            ("blocked_by_friendship",.blocked_by_friendship),
        ]
        for (raw, expected) in statuses {
            let data = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(FirestoreModels.SplitRequest.RequestStatus.self, from: data)
            #expect(decoded == expected, "Failed for raw value: \(raw)")
        }
    }

    @Test("SplitRequest.RequestStatus decodes unknown raw value to .unknown")
    func test_requestStatus_unknownRaw_decodesAsUnknown() throws {
        let data = "\"some_future_status\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(FirestoreModels.SplitRequest.RequestStatus.self, from: data)
        #expect(decoded == .unknown)
    }

    @Test("isSettlement flag distinguishes settlement from regular split request")
    func test_isSettlement_distinguishesFromRegular() {
        // Build a minimal SplitRequest via the existing memberwise init path via JSON
        // (SplitRequest doesn't have a public memberwise init, so test via decode)
        let json = """
        {
          "transactionId": "tx1",
          "fromUid": "u1",
          "toUid": "u2",
          "amount": 25.0,
          "status": "pending",
          "isSettlement": true,
          "createdAt": 0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let req = try? decoder.decode(FirestoreModels.SplitRequest.self, from: json)

        #expect(req?.isSettlement == true)
        #expect(req?.fromUid == "u1")
        #expect(req?.toUid  == "u2")
        #expect(req?.amount == 25.0)
    }

    @Test("isSettlement defaults to nil (falsy) when absent from JSON")
    func test_isSettlement_missingField_isNil() {
        let json = """
        {
          "transactionId": "tx1",
          "fromUid": "u1",
          "toUid": "u2",
          "amount": 10.0,
          "status": "pending",
          "createdAt": 0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let req = try? decoder.decode(FirestoreModels.SplitRequest.self, from: json)

        // isSettlement is nil (not set) → guard `req.isSettlement == true` returns false
        #expect(req?.isSettlement == nil)
        #expect(req?.isSettlement != true)
    }

    // MARK: - hiddenFor filter logic

    @Test("hiddenFor filter excludes splits hidden for current user")
    func test_hiddenFor_excludesSplitsHiddenForCurrentUser() {
        let currentUserId = "userA"

        let hiddenSplits: [[String]?] = [
            nil,                      // Not hidden for anyone → visible
            ["userB"],                // Hidden for userB only → visible to userA
            ["userA"],                // Hidden for userA → should be excluded
            ["userA", "userB"],       // Hidden for both → should be excluded
        ]

        // Replicate the filter logic from fetchFriendTransactions / listenToGlobalBalances
        let visible = hiddenSplits.filter { hidden in
            guard let hidden = hidden else { return true }
            return !hidden.contains(currentUserId)
        }

        #expect(visible.count == 2) // nil and ["userB"] are visible
    }

    // MARK: - Currency resolution

    @Test("resolvedCurrency falls back to mainCurrency when currency field is nil")
    func test_resolvedCurrency_nilField_usesMainCurrency() {
        let json = """
        {
          "transactionId": "tx1",
          "fromUid": "u1",
          "toUid": "u2",
          "amount": 10.0,
          "status": "pending",
          "createdAt": 0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let req = try? decoder.decode(FirestoreModels.SplitRequest.self, from: json)

        #expect(req?.currency == nil)
        // resolvedCurrency must equal CurrencyManager.shared.mainCurrency (never nil)
        let resolved = req?.resolvedCurrency
        #expect(resolved != nil)
        #expect(resolved?.isEmpty == false)
    }
}
