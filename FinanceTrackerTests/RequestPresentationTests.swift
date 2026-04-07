import Testing
import Foundation
@testable import FinanceTracker

@Suite struct RequestPresentationTests {

    private func makeRequest(
        fromUid: String = "sender",
        toUid: String = "receiver",
        amount: Double = 24.5,
        status: FirestoreModels.SplitRequest.RequestStatus = .pending,
        isSettlement: Bool? = nil,
        isGuest: Bool? = nil
    ) -> FirestoreModels.SplitRequest {
        FirestoreModels.SplitRequest(
            id: "req_1",
            transactionId: "tx_1",
            groupId: nil,
            fromUid: fromUid,
            toUid: toUid,
            fromName: "Alice",
            toName: "Bob",
            amount: amount,
            currency: "SGD",
            note: "Dinner",
            category: "Food",
            icon: "fork.knife",
            colorHex: "#FF9500",
            status: status,
            dependencyId: nil,
            lastNudgedAt: nil,
            originalTotalAmount: 49.0,
            isGuest: isGuest,
            isSettlement: isSettlement,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test("incoming pending split is visible on Home and needs accept/decline")
    func incomingPendingSplitPresentation() {
        let request = makeRequest(status: .pending)
        let presentation = request.presentation(for: "receiver", counterpartyName: "Alice")

        #expect(presentation.role == .receiver)
        #expect(presentation.kind == .split)
        #expect(presentation.badge == "Needs Response")
        #expect(presentation.isVisibleOnHome == true)
        #expect(presentation.socialBucket == .actionRequired)
        #expect(presentation.primaryAction == .acceptSplit)
        #expect(presentation.secondaryAction == .declineSplit)
    }

    @Test("incoming accepted split is hidden on Home and stays passive")
    func incomingAcceptedSplitPresentation() {
        let request = makeRequest(status: .accepted)
        let presentation = request.presentation(for: "receiver", counterpartyName: "Alice")

        #expect(presentation.badge == "Accepted")
        #expect(presentation.isVisibleOnHome == false)
        #expect(presentation.primaryAction == nil)
        #expect(presentation.secondaryAction == nil)
        #expect(presentation.detailMessage?.contains("sender will confirm") == true)
    }

    @Test("outgoing accepted split asks sender to confirm payment received")
    func outgoingAcceptedSplitPresentation() {
        let request = makeRequest(fromUid: "me", toUid: "friend", status: .accepted)
        let presentation = request.presentation(for: "me", counterpartyName: "Bob")

        #expect(presentation.role == .sender)
        #expect(presentation.badge == "Awaiting Payment")
        #expect(presentation.socialBucket == .yourRequests)
        #expect(presentation.primaryAction == .confirmPaymentReceived)
        #expect(presentation.secondaryAction == nil)
        #expect(presentation.canConfirmPaymentReceived == true)
    }

    @Test("pending settlement uses settlement-specific actions")
    func pendingSettlementPresentation() {
        let request = makeRequest(status: .pending, isSettlement: true)
        let presentation = request.presentation(for: "receiver", counterpartyName: "Alice")

        #expect(presentation.kind == .settlement)
        #expect(presentation.badge == "Settlement Request")
        #expect(presentation.primaryAction == .acceptSettlement)
        #expect(presentation.secondaryAction == .declineSettlement)
        #expect(presentation.isVisibleOnHome == true)
    }

    @Test("guest split lets the sender confirm payment directly")
    func guestSplitSenderPresentation() {
        let request = makeRequest(fromUid: "me", toUid: "guest_1", status: .pending, isGuest: true)
        let presentation = request.presentation(for: "me", counterpartyName: "Guest")

        #expect(presentation.badge == "Awaiting Payment")
        #expect(presentation.primaryAction == .confirmPaymentReceived)
        #expect(presentation.secondaryAction == .cancelRequest)
        #expect(presentation.canConfirmPaymentReceived == true)
        #expect(request.revertStatusAfterUndoPayment == .pending)
    }
}
