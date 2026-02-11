import Foundation
import FirebaseFirestore
import Combine

class SocialRepository: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Leaderboard Data
    struct LeaderboardEntry: Identifiable {
        let id: String
        let name: String
        let points: Int
    }

    @Published var groupTransactions: [FirestoreModels.GroupTransaction] = []
    @Published var friendTransactions: [FirestoreModels.Transaction] = [] // Shared history
    @Published var leaderboardData: [LeaderboardEntry] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Group Data
    
    func fetchGroupTransactions(groupId: String) {
        self.isLoading = true
        
        db.collection("groups").document(groupId).collection("transactions")
            .order(by: "date", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("Error fetching group transactions: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.groupTransactions = documents.compactMap { doc -> FirestoreModels.GroupTransaction? in
                    try? doc.data(as: FirestoreModels.GroupTransaction.self)
                }
            }
    }
    
    // MARK: - Friend Data
    
    /// Fetches 1-on-1 transaction history (SplitRequests + Shared Transactions)
    func fetchFriendTransactions(currentUserId: String, friendId: String) {
        self.isLoading = true
        self.friendTransactions = []
        
        // We fetch SplitRequests where either:
        // 1. fromUid = current, toUid = friend
        // 2. fromUid = friend, toUid = current
        
        let requestsRef = db.collection("split_requests")
        
        // Firestore doesn't support logical OR in simple queries efficiently for this without multiple listeners or "in" queries on specific fields if structure allows.
        // We will run two listeners or one listener with an "array-contains" if we had a "participants" array.
        // Since we don't have "participants" on SplitRequest, we'll use two queries or a client-side merge if data is small. 
        // Better: Add `participants` array to SplitRequest for easier querying? 
        // For now, let's use two queries and merge locally.
        
        let q1 = requestsRef
            .whereField("fromUid", isEqualTo: currentUserId)
            .whereField("toUid", isEqualTo: friendId)
        
        let q2 = requestsRef
            .whereField("fromUid", isEqualTo: friendId)
            .whereField("toUid", isEqualTo: currentUserId)
        
        // Combined Listener
        // Note: This is a bit simplified. In a real heavy app, we might change schema.
        
        q1.addSnapshotListener { [weak self] snap1, err1 in
            guard let self = self else { return }
            if let err = err1 { print("Error q1: \(err)"); return }
            
                Task { @MainActor in
                    do {
                        let snap2 = try await q2.getDocuments()
                        

                        var combined: [FirestoreModels.Transaction] = []
                        
                        let docs1 = snap1?.documents ?? []
                        let docs2 = snap2.documents
                        let allDocs = docs1 + docs2
                        
                        // Explicitly decode on MainActor loop to avoid "nonisolated context" error
                        var requests: [FirestoreModels.SplitRequest] = []
                        for doc in allDocs {
                            if let req = try? doc.data(as: FirestoreModels.SplitRequest.self) {
                                requests.append(req)
                            }
                        }
                        
                        // Convert to Transactions
                        combined = requests.map { req in
                            let isPayer = req.fromUid == currentUserId
                            
                            return FirestoreModels.Transaction(
                                id: req.id,
                                title: req.note ?? "Split Request",
                                subtitle: isPayer ? "You requested" : "\(req.fromName ?? "Friend") requested",
                                amount: req.amount,
                                date: req.createdAt,
                                icon: "arrow.left.arrow.right",
                                colorHex: isPayer ? "#34C759" : "#FF3B30",
                                note: req.status.rawValue,
                                type: isPayer ? "income" : "expense",
                                userId: currentUserId,
                                createdAt: req.createdAt
                            )
                        }
                        
                        self.friendTransactions = combined.sorted(by: { $0.date > $1.date })
                        self.isLoading = false
                        
                    } catch {
                        print("Error fetching friend transactions: \(error)")
                    }
                }
        }
    }
    
    // MARK: - Balances
    
    /// Calculates the net balance with a friend
    /// Returns: Positive if they owe YOU, Negative if you owe THEM.
    /// Calculates the net balance with a friend, grouped by currency
    /// Returns: Dictionary of [CurrencyCode: Amount] where positive if they owe YOU, negative if you owe THEM.
    func calculateFriendBalance(currentUserId: String, friendId: String) async -> [String: Double] {
        let requestsRef = db.collection("split_requests")
        
        // 1. You paid/requested (They owe you) - Status: Pending or Accepted
        let q1 = try? await requestsRef
            .whereField("fromUid", isEqualTo: currentUserId)
            .whereField("toUid", isEqualTo: friendId)
            .getDocuments()
        
        // 2. They paid/requested (You owe them)
        let q2 = try? await requestsRef
            .whereField("fromUid", isEqualTo: friendId)
            .whereField("toUid", isEqualTo: currentUserId)
            .getDocuments()
            
        let sent = q1?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
        let received = q2?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
        
        var balances: [String: Double] = [:]
        let mainCurrency = CurrencyManager.shared.mainCurrency
        
        // Calculate Owed To You (Positive)
        for req in sent where req.status == .pending || req.status == .accepted {
            let currency = req.currency ?? mainCurrency
            balances[currency, default: 0] += req.amount
        }
        
        // Calculate You Owe (Negative)
        for req in received where req.status == .pending || req.status == .accepted {
            let currency = req.currency ?? mainCurrency
            balances[currency, default: 0] -= req.amount
        }
        
        // Filter out zero balances
        return balances.filter { abs($0.value) > 0.01 }
    }
    
    /// Sends a nudge notification to a friend for unpaid debts
    func sendNudge(to friendId: String, currentUserId: String) async throws {
        // 1. Find pending requests from current user to friend
        let snapshot = try await db.collection("split_requests")
            .whereField("fromUid", isEqualTo: currentUserId)
            .whereField("toUid", isEqualTo: friendId)
            .whereField("status", isEqualTo: FirestoreModels.SplitRequest.RequestStatus.pending.rawValue)
            .getDocuments()
            
        let batch = db.batch()
        let now = Date()
        
        // 2. Update lastNudgedAt timestamp
        for doc in snapshot.documents {
            batch.updateData(["lastNudgedAt": now], forDocument: doc.reference)
        }
        
        // 3. Commit update
        try await batch.commit()
        
        // Note: Real push notification would be triggered via Cloud Functions watching this field update
        // or a separate notifications collection.
    }
    
    /// Calculates balances for all members in a group
    /// Returns: Dictionary of [MemberID: NetBalance] relative to Current User (or total logic?)
    /// Actually, for Group View, we usually want "Who owes what in total".
    /// Simplified View: How much *Current User* owes or is owed in this group context.
    func calculateGroupBalances(groupId: String, currentUserId: String) async -> [String: Double] {
        // We fetch all non-settled requests tagged with this groupId
        
        let q = try? await db.collection("split_requests")
            .whereField("groupId", isEqualTo: groupId)
            //.whereField("status", in: ["pending", "accepted"])
            .getDocuments()
            
        let requests = q?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
        let activeRequests = requests.filter { $0.status == .pending || $0.status == .accepted }
        
        var balances: [String: Double] = [:]
        
        // Initialize for current user context is tricky.
        // Let's just calculate "Net Position" for everyone in the group?
        // Net Position = Total Paid (Requests Sent) - Total Consumed (Requests Received)
        
        for req in activeRequests {
            balances[req.fromUid, default: 0] += req.amount // They paid, so they are +
            balances[req.toUid, default: 0] -= req.amount   // They consumed, so they are -
        }
        
        return balances
    }
    
    struct DebtInstruction: Identifiable {
        let id = UUID()
        let debtorId: String
        let creditorId: String
        let amount: Double
    }
    
    /// Converts Net Balances into specific "Who owes Who" instructions (Debt Simplification)
    func calculateDebtResolution(balances: [String: Double]) -> [DebtInstruction] {
        var debtors = balances.filter { $0.value < -0.01 }.map { ($0.key, $0.value) }.sorted { $0.1 < $1.1 } // Most negative first
        var creditors = balances.filter { $0.value > 0.01 }.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 } // Most positive first
        
        var instructions: [DebtInstruction] = []
        
        var debtorIndex = 0
        var creditorIndex = 0
        
        while debtorIndex < debtors.count && creditorIndex < creditors.count {
            let debtor = debtors[debtorIndex]
            let creditor = creditors[creditorIndex]
            
            // Amount to settle is min of what debtor owes and what creditor is owed
            let amount = min(abs(debtor.1), creditor.1)
            
            instructions.append(DebtInstruction(debtorId: debtor.0, creditorId: creditor.0, amount: amount))
            
            // Update remaining
            debtors[debtorIndex].1 += amount
            creditors[creditorIndex].1 -= amount
            
            // Move indices if settled (allow small float error)
            if abs(debtors[debtorIndex].1) < 0.01 { debtorIndex += 1 }
            if creditors[creditorIndex].1 < 0.01 { creditorIndex += 1 }
        }
        
        return instructions
    }
    
    // MARK: - Leaderboard Logic
    
    /// Fetches gamification points for all friends + current user and sorts them
    func fetchLeaderboard(friends: [FirestoreModels.Friend], currentUser: (id: String, name: String)) {
        guard !isLoading else { return }
        self.isLoading = true
        
        var allIds = friends.compactMap { $0.id }
        allIds.append(currentUser.id)
        // Remove duplicates just in case
        allIds = Array(Set(allIds))
        
        
        Task {
            var entries: [LeaderboardEntry] = []
            
            await withTaskGroup(of: LeaderboardEntry?.self) { group in
                for uid in allIds {
                    group.addTask {
                        do {
                            let snapshot = try await self.db.collection("users").document(uid).getDocument()
                            if let data = snapshot.data() {
                                let name = data["name"] as? String ?? "Unknown"
                                let points = data["points"] as? Int ?? 0
                                return LeaderboardEntry(id: uid, name: name, points: points)
                            }
                        } catch {
                            print("Error fetching user \(uid) for leaderboard: \(error)")
                        }
                        return nil
                    }
                }
                
                for await entry in group {
                    if let entry = entry {
                        entries.append(entry)
                    }
                }
            }
            
            // Sort Descending
            let sorted = entries.sorted { $0.points > $1.points }
            
            DispatchQueue.main.async {
                self.leaderboardData = sorted
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Actions
    
    func settleUp(payerId: String, receiverId: String, groupId: String?, amount: Double, method: String = "Cash") async throws {
        // 1. Create a "Payment" transaction
        let paymentTransaction = FirestoreModels.Transaction(
            title: "Payment to \(method)",
            subtitle: "Settle Up",
            amount: -amount, // Expense for payer
            date: Date(),
            icon: "banknote.fill",
            colorHex: "#34C759", // Green
            note: "Settled up via \(method)",
            type: "expense",
            userId: payerId,
            createdAt: Date()
        )
        
        let batch = db.batch()
        
        // Payer Side (Expense)
        let payerRef = db.collection("users").document(payerId).collection("transactions").document()
        try batch.setData(from: paymentTransaction, forDocument: payerRef)
        
        // Receiver Side (Income)
        // NOTE: We cannot write to another user's private `transactions` subcollection due to security rules.
        // The receiver will see this "Income" via the `calculateFriendBalance` logic (which sums SplitRequests)
        // or we could implement a Cloud Function to create this transaction securely.
        // For now, we rely on the SplitRequest (Paid) to adjust the balance.
        
        // If we want the receiver to have a record in their "Transactions" list, they would need to accept/confirm it,
        // or we use a shared "Settlements" collection. 
        // Given the "Wizard" UI implies instant settlement, we trust the Payer for the Balance calculation,
        // but we skip creating the private Transaction doc for the Receiver to avoid permission errors.

        
        // 3. Counter-Request to neutralize balance
        // If Payer owes Receiver, it means Receiver previously requested money (From: Receiver, To: Payer).
        // To offset this, Payer creates a request (From: Payer, To: Receiver) for the amount.
        // This request represents "I gave you money".
        let requestRef = db.collection("split_requests").document()
        let counterRequest = FirestoreModels.SplitRequest(
            id: nil,
            transactionId: payerRef.documentID, // Link to payment
            groupId: groupId,
            fromUid: payerId,
            toUid: receiverId,
            fromName: "Settlement", // Special name logic handled in UI usually, but good fallback
            amount: amount,
            currency: nil,
            note: "Settled via \(method)",
            status: .accepted, // Mark as accepted (Active Credit) to offset debt. Not .paid (Resolved/Ignored).
            dependencyId: nil,
            lastNudgedAt: nil,
            createdAt: Date()
        )
        try batch.setData(from: counterRequest, forDocument: requestRef)
        
        // Group Feed (if applicable)
        if let groupId = groupId {
            let groupRef = db.collection("groups").document(groupId).collection("transactions").document()
            let groupTx = FirestoreModels.GroupTransaction(
                id: nil,
                title: "Settlement: \(method)",
                amount: amount,
                payerId: payerId,
                payerName: "Payer", // Should fetch real name
                date: Date(),
                type: "settlement",
                currencyCode: nil
            )
            try batch.setData(from: groupTx, forDocument: groupRef)
        }
        
        try await batch.commit()
    }
    // MARK: - Group Split Management
    
    /// Fetches all active splits in a group involving the current user (either Payer or Payee)
    func fetchMyGroupSplits(groupId: String, currentUserId: String) async -> [FirestoreModels.SplitRequest] {
        let requestsRef = db.collection("split_requests")
        
        // 1. You owe someone (Incoming)
        let q1 = try? await requestsRef
            .whereField("groupId", isEqualTo: groupId)
            .whereField("toUid", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "pending") // Only show pending for "Tick to Pay"
            .getDocuments()
            
        // 2. Someone owes you (Outgoing) - Optional: Do we want to show these?
        // User asked: "Clear outstanding... check tickbox when friend pays".
        // So yes, if I am David, and John owes me, I want to check it off.
        let q2 = try? await requestsRef
            .whereField("groupId", isEqualTo: groupId)
            .whereField("fromUid", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
            
        let incoming = q1?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
        let outgoing = q2?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
        
        return (incoming + outgoing).sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    /// Marks a split as paid and posts a group feed update safely using a Batch
    func markSplitAsPaid(request: FirestoreModels.SplitRequest, currentUserId: String, currentUserName: String) async throws {
        guard let requestId = request.id, let groupId = request.groupId else { return }
        
        let batch = db.batch()
        
        // 1. Update Request Status to .paid
        let requestRef = db.collection("split_requests").document(requestId)
        batch.updateData(["status": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue], forDocument: requestRef)
        
        // 2. Create Group Activity Feed Item
        // Logic: "David paid John $20 for Dinner"
        
        // Creditor Name (Who receives money)
        let creditorName = request.fromUid == currentUserId ? "You" : (request.fromName ?? "Friend")
        
        // Feed Message Construction
        let feedTitle = "Payment: \(request.note ?? "Split")"
        // If current user is the Debtor (Paying): "You paid Creditor"
        // If current user is the Creditor (Marking confirmed): "Debtor paid You"
        
        let feedPayerName: String
        if currentUserId == request.toUid {
            feedPayerName = "You paid \(creditorName)" // "You paid Bob"
        } else {
            feedPayerName = "\(request.toUid == currentUserId ? "You" : "Friend") paid You" // Rough fallback, ideally we have debtor name
        }
        
        let groupRef = db.collection("groups").document(groupId).collection("transactions").document()
        let groupTx = FirestoreModels.GroupTransaction(
            id: nil,
            title: feedTitle,
            amount: request.amount,
            payerId: request.toUid, // The Debtor is the "Payer" in a settlement
            payerName: feedPayerName, // Descriptive subtitle
            date: Date(),
            type: "settlement",
            currencyCode: request.currency
        )
        
        try batch.setData(from: groupTx, forDocument: groupRef)
        
        try await batch.commit()
    }
    
    /// Reverts a paid split to pending (Undo)
    func unmarkSplitAsPaid(request: FirestoreModels.SplitRequest) async throws {
        guard let requestId = request.id else { return }
        // We don't delete the feed item because it's a log, but we could if we tracked the linked feed ID.
        // For now, just reverting the status is enough to bring it back to the list.
        try await db.collection("split_requests").document(requestId).updateData([
            "status": FirestoreModels.SplitRequest.RequestStatus.pending.rawValue
        ])
    }
    
    // MARK: - Deletion Logic
    
    /// Deletes a group transaction and cascades to the original transaction and split requests
    func deleteGroupTransaction(groupTx: FirestoreModels.GroupTransaction, groupId: String, currentUserId: String) async throws {
        // 1. Verify permission (only payer can delete)
        guard groupTx.payerId == currentUserId else {
            // Throw/Error or just return. For now, strict check.
            return
        }
        
        let batch = db.batch()
        
        // 2. Delete Group Transaction
        if let txId = groupTx.id {
            let groupRef = db.collection("groups").document(groupId).collection("transactions").document(txId)
            batch.deleteDocument(groupRef)
        }
        
        // 3. Cascade to Original Transaction & Splits
        // Only if we have the link
        if let originalId = groupTx.originalTransactionId {
            // A. Delete Original User Transaction
            let originalRef = db.collection("users").document(currentUserId).collection("transactions").document(originalId)
            batch.deleteDocument(originalRef)
            
            // B. Find and Delete Split Requests
            let splits = try await fetchSplitsForTransaction(transactionId: originalId)
            for split in splits {
                 if let splitId = split.id {
                     let splitRef = db.collection("split_requests").document(splitId)
                     batch.deleteDocument(splitRef)
                 }
            }
        }
        
        try await batch.commit()
    }
    
    /// Deletes a friend transaction (Split Request)
    func deleteFriendTransaction(transaction: FirestoreModels.Transaction, currentUserId: String) async throws {
        // transaction.id corresponds to the SplitRequest ID in the Friend Feed
        guard let requestId = transaction.id else { return }
        
        // We fetch the request to confirm ownership before delete
        let requestRef = db.collection("split_requests").document(requestId)
        let snapshot = try await requestRef.getDocument()
        
        if let request = try? snapshot.data(as: FirestoreModels.SplitRequest.self) {
            if request.fromUid == currentUserId {
                // We are the creator, we can delete the request
                try await requestRef.delete()
                
                // Note: We are NOT deleting the original transaction here as it implies 1-on-1 specific logic 
                // and we don't have the "GroupTransaction" wrapper to easily identify the "Event".
                // If the user wants to delete the "Expense", they should do it from All Transactions.
                // But for "Split History", removing the request is the primary action.
            }
        }
    }

    func fetchSplitsForTransaction(transactionId: String) async throws -> [FirestoreModels.SplitRequest] {
        let snapshot = try await db.collection("split_requests")
            .whereField("transactionId", isEqualTo: transactionId)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) }
    }
}
