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

    @Published var friendBalances: [String: Double] = [:] // Real-time balance
    @Published var groupTransactions: [FirestoreModels.GroupTransaction] = []
    @Published var friendTransactions: [FirestoreModels.Transaction] = [] // Shared history
    @Published var leaderboardData: [LeaderboardEntry] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Group Data
    
    func fetchGroupTransactions(groupId: String) {
        // ... (unchanged)
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
    
    private var friendTransactionsListener1: ListenerRegistration?
    private var friendTransactionsListener2: ListenerRegistration?

    /// Fetches 1-on-1 transaction history (SplitRequests + Shared Transactions)
    func fetchFriendTransactions(currentUserId: String, friendId: String) {
        self.isLoading = true
        self.friendTransactions = []
        // self.friendBalances = [:] // Keep old balance or clear? Better keep to avoid flicker, or clear if ID changed.
        
        // Cancel previous listeners
        friendTransactionsListener1?.remove()
        friendTransactionsListener2?.remove()
        
        // Query 1: Requests SENT by YOU (from: You, to: Friend)
        let q1 = db.collection("split_requests")
            .whereField("fromUid", isEqualTo: currentUserId)
            .whereField("toUid", isEqualTo: friendId)
        
        // Query 2: Requests RECEIVED by YOU (from: Friend, to: You)
        let q2 = db.collection("split_requests")
            .whereField("fromUid", isEqualTo: friendId)
            .whereField("toUid", isEqualTo: currentUserId)
        
        var sentRequests: [FirestoreModels.SplitRequest] = []
        var receivedRequests: [FirestoreModels.SplitRequest] = []
        
        // Helper to merge and publish
        let updateBlock = { [weak self] in
            guard let self = self else { return }
            
            // Explicitly decode/map on MainActor loop or just publish
            let allRequests = sentRequests + receivedRequests
            
            // 1. Map Transactions
            let combined = allRequests.map { req -> FirestoreModels.Transaction in
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
                    source: req.transactionId, // ✅ Pass Original Transaction ID here for reconstruction
                    userId: currentUserId,
                    createdAt: req.createdAt
                )
            }
            
            // 2. Calculate Balances
            var newBalances: [String: Double] = [:]
            let mainCurrency = CurrencyManager.shared.mainCurrency
            
            // Owed To You (Positive)
            for req in sentRequests where req.status == .pending || req.status == .accepted {
                let currency = req.currency ?? mainCurrency
                newBalances[currency, default: 0] += req.amount
            }
            
            // You Owe (Negative)
            for req in receivedRequests where req.status == .pending || req.status == .accepted {
                let currency = req.currency ?? mainCurrency
                newBalances[currency, default: 0] -= req.amount
            }
            // Filter zero
            let filteredBalances = newBalances.filter { abs($0.value) > 0.01 }
            
            DispatchQueue.main.async {
                self.friendTransactions = combined.sorted(by: { $0.date > $1.date })
                self.friendBalances = filteredBalances
                self.isLoading = false
            }
        }
        
        // Listener 1 (Sent)
        friendTransactionsListener1 = q1.addSnapshotListener { [weak self] snapshot, error in
            guard let _ = self else { return }
            if let error = error { print("Error listening to sent requests: \(error)"); return }
            
            sentRequests = snapshot?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
            updateBlock()
        }
        
        // Listener 2 (Received)
        friendTransactionsListener2 = q2.addSnapshotListener { [weak self] snapshot, error in
            guard let _ = self else { return }
            if let error = error { print("Error listening to received requests: \(error)"); return }
            
            receivedRequests = snapshot?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
            updateBlock()
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
    
    func settleUp(payerId: String, receiverId: String, groupId: String?, amount: Double, payerName: String = "Member", method: String = "Cash") async throws {
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

        
        // 3. Counter-Request (Settlement)
        // Settlement Request acts as a Credit to offset the Debt.
        // It is FROM Payer TO Reciever, status .accepted.
        
        let requestRef = db.collection("split_requests").document()
        let settlementRequest = FirestoreModels.SplitRequest(
             id: nil,
             transactionId: payerRef.documentID,
             groupId: groupId,
             fromUid: payerId,
             toUid: receiverId,
             fromName: "Settlement",
             amount: amount,
             currency: nil,
             note: "Settled via \(method)",
             status: .accepted, 
             dependencyId: nil,
             lastNudgedAt: nil,
             createdAt: Date()
        )
        
        try batch.setData(from: settlementRequest, forDocument: requestRef)
        
        // Group Feed
        if let groupId = groupId {
            let groupRef = db.collection("groups").document(groupId).collection("transactions").document()
            let groupTx = FirestoreModels.GroupTransaction(
                id: nil,
                title: "Settlement: \(method)",
                amount: amount,
                payerId: payerId,
                payerName: payerName, 
                date: Date(),
                type: "settlement", // Special type
                currencyCode: nil
            )
            try batch.setData(from: groupTx, forDocument: groupRef)
        }
        
        // 4. Mark existing pending splits between these users as paid
        // Find splits where the receiver (creditor) split bills with the payer (debtor)
        let pendingSplits = try await db.collection("split_requests")
            .whereField("fromUid", isEqualTo: receiverId)
            .whereField("toUid", isEqualTo: payerId)
            .getDocuments()
        
        for doc in pendingSplits.documents {
            if let statusStr = doc.get("status") as? String,
               let status = FirestoreModels.SplitRequest.RequestStatus(rawValue: statusStr),
               status == .pending || status == .accepted {
                // Mark the split request as paid
                batch.updateData(["status": FirestoreModels.SplitRequest.RequestStatus.paid.rawValue], forDocument: doc.reference)
                
                // Sync the original transaction's split to show as paid
                if let originalTxId = doc.get("transactionId") as? String {
                    let txRef = db.collection("users").document(receiverId).collection("transactions").document(originalTxId)
                    do {
                        let txSnapshot = try await txRef.getDocument()
                        if let txData = try? txSnapshot.data(as: FirestoreModels.Transaction.self), var splits = txData.splits {
                            if let index = splits.firstIndex(where: {
                                $0.requestId == doc.documentID ||
                                ($0.friendId == payerId && !$0.isPaid) ||
                                ($0.guestId == payerId && !$0.isPaid)
                            }) {
                                splits[index].isPaid = true
                                splits[index].paidDate = Date()
                                var updatedTx = txData
                                updatedTx.splits = splits
                                try batch.setData(from: updatedTx, forDocument: txRef)
                            }
                        }
                    } catch {
                        print("DEBUG: Error syncing split during settle up: \(error)")
                    }
                }
            }
        }
        
        try await batch.commit()
    }
    // MARK: - Group Split Management
    
    /// Fetches all active splits in a group involving the current user (either Payer or Payee)
    func fetchMyGroupSplits(groupId: String, currentUserId: String) async -> [FirestoreModels.SplitRequest] {
        let requestsRef = db.collection("split_requests")
        
        // 1. You owe someone (Incoming)
        let q1: QuerySnapshot? = try? await requestsRef
            .whereField("groupId", isEqualTo: groupId)
            .whereField("toUid", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "pending") // Only show pending for "Tick to Pay"
            .getDocuments()
            
        // 2. Someone owes you (Outgoing) - Optional: Do we want to show these?
        // User asked: "Clear outstanding... check tickbox when friend pays".
        // So yes, if I am David, and John owes me, I want to check it off.
        let q2: QuerySnapshot? = try? await requestsRef
            .whereField("groupId", isEqualTo: groupId)
            .whereField("fromUid", isEqualTo: currentUserId)
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
            
        let incoming = q1?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
        let outgoing = q2?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
        
        return (incoming + outgoing).sorted(by: { $0.createdAt > $1.createdAt })
    }
    
    // markSplitAsPaid and unmarkSplitAsPaid are consolidated in SocialTransactionManager.shared
    
    // MARK: - Deletion Logic
    
    /// Deletes a group transaction and cascades to the original transaction and split requests
    func deleteGroupTransaction(groupTx: FirestoreModels.GroupTransaction, groupId: String, currentUserId: String) async throws {
        // 1. Verify permission (only payer can delete)
        guard groupTx.payerId == currentUserId else {
             throw NSError(domain: "SocialRepository", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the payer can delete this transaction."])
        }
        
        let batch = db.batch()
        
        // 2. Delete Group Transaction
        if let txId = groupTx.id {
            let groupRef = db.collection("groups").document(groupId).collection("transactions").document(txId)
            batch.deleteDocument(groupRef)
        }
        
        // 3. Cascade to Original Transaction & Splits
        if let originalId = groupTx.originalTransactionId {
            let originalRef = db.collection("users").document(currentUserId).collection("transactions").document(originalId)
            
            // A. Fetch original transaction to find income transaction IDs from paid splits
            do {
                let txSnapshot = try await originalRef.getDocument()
                if let txData = try? txSnapshot.data(as: FirestoreModels.Transaction.self), let splits = txData.splits {
                    for split in splits {
                        if let incomeId = split.incomeTransactionId {
                            // Delete the "Payment Received" income transaction
                            let incomeRef = db.collection("users").document(currentUserId).collection("transactions").document(incomeId)
                            batch.deleteDocument(incomeRef)
                        }
                    }
                }
            } catch {
                print("DEBUG: Error fetching original transaction for income cleanup: \(error)")
            }
            
            // B. Delete Original User Transaction
            batch.deleteDocument(originalRef)
            
            // C. Find and Delete Split Requests
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
    
    /// Deletes a friend transaction (Split Request) and cascades to Group feed
    func deleteFriendTransaction(transaction: FirestoreModels.Transaction, currentUserId: String) async throws {
        // transaction.id corresponds to the SplitRequest ID in the Friend Feed
        guard let requestId = transaction.id else { return }
        
        // Fetch the request to get full details
        let requestRef = db.collection("split_requests").document(requestId)
        let snapshot = try await requestRef.getDocument()
        
        guard let request = try? snapshot.data(as: FirestoreModels.SplitRequest.self),
              request.fromUid == currentUserId || request.toUid == currentUserId else {
            return
        }
        
        let batch = db.batch()
        
        // 1. Remove the split from the original transaction's splits array
        let payorId = request.fromUid
        let txRef = db.collection("users").document(payorId).collection("transactions").document(request.transactionId)
        var isLastSplit = false
        
        do {
            let txSnapshot = try await txRef.getDocument()
            if let txData = try? txSnapshot.data(as: FirestoreModels.Transaction.self), var splits = txData.splits {
                // Find and remove the matching split
                if let index = splits.firstIndex(where: {
                    $0.requestId == requestId ||
                    ($0.friendId == request.toUid) ||
                    ($0.guestId == request.toUid)
                }) {
                    // 2. If the split was paid and had an income transaction, delete it
                    if let incomeId = splits[index].incomeTransactionId {
                        let incomeRef = db.collection("users").document(payorId).collection("transactions").document(incomeId)
                        batch.deleteDocument(incomeRef)
                    }
                    
                    // Remove the split — payor now absorbs this portion
                    splits.remove(at: index)
                    isLastSplit = splits.isEmpty
                    
                    var updatedTx = txData
                    updatedTx.splits = isLastSplit ? nil : splits
                    try batch.setData(from: updatedTx, forDocument: txRef)
                }
            }
        } catch {
            print("DEBUG: Error updating original transaction during friend delete: \(error)")
        }
        
        // 3. Delete the SplitRequest
        batch.deleteDocument(requestRef)
        
        // 4. Cascade to Group feed (Fix #1 + #3)
        if let groupId = request.groupId {
            // Find the GroupTransaction linked to the original transaction
            let groupTxQuery = try await db.collection("groups").document(groupId).collection("transactions")
                .whereField("originalTransactionId", isEqualTo: request.transactionId)
                .getDocuments()
            
            if isLastSplit {
                // Last split deleted — remove the entire GroupTransaction feed item
                for doc in groupTxQuery.documents {
                    batch.deleteDocument(doc.reference)
                }
            }
            // If not the last split, group feed still valid (other participants remain)
        }
        
        try await batch.commit()
        print("DEBUG: Cascade deleted split request \(requestId), removed split from original transaction, and synced group feed")
    }

    func fetchSplitsForTransaction(transactionId: String) async throws -> [FirestoreModels.SplitRequest] {
        let snapshot = try await db.collection("split_requests")
            .whereField("transactionId", isEqualTo: transactionId)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) }
    }
    
    /// OPTIMISTIC UPDATE: Removes a transaction from the local list immediately
    func removeLocalTransaction(id: String) {
        self.friendTransactions.removeAll { $0.id == id }
    }
}
