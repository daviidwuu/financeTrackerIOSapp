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
    @Published var groupBalances: [String: Double] = [:] // Real-time group balances
    
    // Global Social Balances (Net Worth)
    @Published var totalOwedToYou: Double = 0
    @Published var totalYouOwe: Double = 0
    
    @Published var groupTransactions: [FirestoreModels.GroupTransaction] = []
    @Published var friendTransactions: [FirestoreModels.TransactionModel] = [] // Shared history
    @Published var leaderboardData: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String? // ✅ NEW: Error handling
    
    // MARK: - Group Split Management
    @Published var myPendingGroupSplits: [FirestoreModels.SplitRequest] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Global Balance Logic
    
    private var globalSentListener: ListenerRegistration?
    private var globalReceivedListener: ListenerRegistration?
    
    /// Listens to ALL active debts across all groups and friends
    func listenToGlobalBalances(currentUserId: String) {
        // Cancel existing
        globalSentListener?.remove()
        globalReceivedListener?.remove()
        
        // 1. You Sent (Owed To You)
        let sentQuery = db.collection("split_requests")
            .whereField("fromUid", isEqualTo: currentUserId)
            .whereField("status", in: ["pending", "accepted"])
            
        // 2. You Received (You Owe)
        let receivedQuery = db.collection("split_requests")
            .whereField("toUid", isEqualTo: currentUserId)
            .whereField("status", in: ["pending", "accepted"])
            
        var sentTotal: Double = 0
        var receivedTotal: Double = 0
        
        let updateBlock = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.totalOwedToYou = sentTotal
                self.totalYouOwe = receivedTotal
            }
        }
        
        globalSentListener = sentQuery.addSnapshotListener { snapshot, error in
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Failed to sync owed balances: \(error.localizedDescription)" }
                return
            }
            guard let docs = snapshot?.documents else { return }
            
            sentTotal = docs.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) }
                .reduce(0) { $0 + $1.amount }
            updateBlock()
        }
        
        globalReceivedListener = receivedQuery.addSnapshotListener { snapshot, error in
            if let error = error {
                DispatchQueue.main.async { self.errorMessage = "Failed to sync owed balances: \(error.localizedDescription)" }
                return
            }
            guard let docs = snapshot?.documents else { return }
            
            receivedTotal = docs.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) }
                .reduce(0) { $0 + $1.amount }
            updateBlock()
        }
    }

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
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Failed to load group transactions: \(error.localizedDescription)"
                    }
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
            
            let allRequests = sentRequests + receivedRequests
            
            // 1. Map Transactions
            let combined = allRequests.map { req -> FirestoreModels.TransactionModel in
                let isPayer = req.fromUid == currentUserId
                
                return FirestoreModels.TransactionModel(
                    id: req.id,
                    userId: currentUserId,
                    title: req.note ?? "Split Request",
                    subtitle: isPayer ? "You requested" : "\(req.fromName ?? "Friend") requested",
                    amount: req.amount,
                    date: req.createdAt,
                    type: isPayer ? "income" : "expense",
                    createdAt: req.createdAt,
                    icon: "arrow.left.arrow.right",
                    colorHex: isPayer ? "#34C759" : "#FF3B30",
                    note: req.status.rawValue,
                    source: req.transactionId // Pass Original Transaction ID
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
    
    /// Calculates the net balance with a friend, grouped by currency
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
    
    private var groupBalancesListener: ListenerRegistration?
    
    /// Listens to group balances and pending splits
    func listenToGroupBalances(groupId: String, currentUserId: String) {
        let requestsRef = db.collection("split_requests")
        
        groupBalancesListener?.remove()
        
        groupBalancesListener = requestsRef
            .whereField("groupId", isEqualTo: groupId)
            .whereField("status", in: ["pending", "accepted"])
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error listening to group balances: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                let activeRequests = documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) }
                
                var balances: [String: Double] = [:]
                
                // Net Position = Total Paid (Requests Sent) - Total Consumed (Requests Received)
                for req in activeRequests {
                    // Payer (Credential) gains positive balance
                    balances[req.fromUid, default: 0] += req.amount
                    // Receiver (Debtor) gets negative balance
                    balances[req.toUid, default: 0] -= req.amount
                }
                
                // Filter for "My Pending Splits" (Real-time)
                let mySplits = activeRequests.filter { req in
                    return req.status == .pending && (req.toUid == currentUserId || req.fromUid == currentUserId)
                }.sorted(by: { $0.createdAt > $1.createdAt })
                
                DispatchQueue.main.async {
                    self.groupBalances = balances
                    self.myPendingGroupSplits = mySplits
                }
            }
    }
    
    /// Calculates balances for all members in a group (One-shot)
    func calculateGroupBalances(groupId: String, currentUserId: String) async -> [String: Double] {
        let requestsRef = db.collection("split_requests")
        
        do {
            // 1. You owe someone (Incoming) - Status: Pending or Accepted
            let snapshot = try await requestsRef
                .whereField("groupId", isEqualTo: groupId)
                .getDocuments()
                
            let activeRequests = snapshot.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) }
                .filter { $0.status == .pending || $0.status == .accepted }
            
            var balances: [String: Double] = [:]
            
            // Net Position = Total Paid (Requests Sent) - Total Consumed (Requests Received)
            for req in activeRequests {
                // Payer (Credential) gains positive balance
                balances[req.fromUid, default: 0] += req.amount
                // Receiver (Debtor) gets negative balance
                balances[req.toUid, default: 0] -= req.amount
            }
            
            return balances
        } catch {
            print("Error calculating group balances: \(error)")
            return [:]
        }
    }
    
    // Derived Debt Instructions (Helper)
    func getDebtInstructions() -> [DebtInstruction] {
        return DebtCalculator.shared.calculateDebtResolution(balances: groupBalances)
    }
    
    // MARK: - Actions
    
    func sendNudge(friendId: String) async throws {
        // In a real app, this would send a push notification
        // For now, we'll just simulate a network call
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    func deleteFriendTransaction(transactionId: String) async throws {
        // 1. Delete the split request
        try await db.collection("split_requests").document(transactionId).delete()
        
        // 2. Optimistically remove from local list
        await MainActor.run {
            self.friendTransactions.removeAll { $0.id == transactionId }
        }
    }
    
    func deleteGroupTransaction(transactionId: String, groupId: String) async throws {
        // 1. Delete the transaction document
        try await db.collection("groups").document(groupId).collection("transactions").document(transactionId).delete()
        
        // 2. Also find and delete associated split requests
        let splitsSnapshot = try await db.collection("split_requests")
            .whereField("transactionId", isEqualTo: transactionId)
            .getDocuments()
            
        let batch = db.batch()
        for doc in splitsSnapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
        
        // 3. Optimistically remove
        await MainActor.run {
            self.groupTransactions.removeAll { $0.id == transactionId }
        }
    }
    
    func calculateDebtResolution(balances: [String: Double]) -> [DebtInstruction] {
        return DebtCalculator.shared.calculateDebtResolution(balances: balances)
    }
    
    func settleUp(payerId: String, receiverId: String, groupId: String?, amount: Double, payerName: String? = nil, method: String) async throws {
        let settlementId = UUID().uuidString
        let timestamp = Date()
        
        // 1. Create a settlement transaction (SplitRequest with type 'settlement')
        let settlement = FirestoreModels.SplitRequest(
            id: settlementId,
            transactionId: settlementId, // Self-reference for settlements
            groupId: groupId,
            fromUid: payerId, // Sender of money
            toUid: receiverId, // Receiver of money
            fromName: payerName ?? "User", // We might need to fetch names if nil
            toName: nil,
            amount: amount,
            currency: CurrencyManager.shared.mainCurrency,
            note: "Settlement via \(method)",
            status: .accepted, // Settlements are auto-accepted usually
            dependencyId: nil,
            lastNudgedAt: nil,
            createdAt: timestamp
        )
        
        try db.collection("split_requests").document(settlementId).setData(from: settlement)
        
        // 2. If Group Context, Add to Group History
        if let groupId = groupId {
            let groupTx = FirestoreModels.GroupTransaction(
                id: settlementId,
                title: "Settlement",
                amount: amount,
                payerId: payerId,
                payerName: payerName ?? "User",
                date: timestamp,
                type: "settlement", // Special type for UI
                currencyCode: CurrencyManager.shared.mainCurrency,
                note: "Paid via \(method)",
                category: "Transfer",
                icon: "banknote.fill",
                colorHex: "#34C759", // Green
                originalTransactionId: nil,
                editHistory: nil
            )
            
            try db.collection("groups").document(groupId).collection("transactions").document(settlementId).setData(from: groupTx)
        }
    }
    
    func mergeGuestToFriend(guestId: String, friend: FirestoreModels.Friend, currentUserId: String) async throws {
        guard let friendId = friend.id else { return }
        
        // 1. Find all split_requests involving the guest
        // Case A: Guest was 'toUid' (You owed guest or guest owed you)
        let q1 = try await db.collection("split_requests")
            .whereField("toUid", isEqualTo: guestId)
            .getDocuments()
            
        // Case B: Guest was 'fromUid'
        let q2 = try await db.collection("split_requests")
            .whereField("fromUid", isEqualTo: guestId)
            .getDocuments()
            
        let batch = db.batch()
        
        // Update toUid -> friendId
        for doc in q1.documents {
            batch.updateData(["toUid": friendId], forDocument: doc.reference)
        }
        
        // Update fromUid -> friendId
        for doc in q2.documents {
            batch.updateData(["fromUid": friendId, "fromName": friend.name], forDocument: doc.reference)
        }
        
        // 2. Delete the guest
        let guestRef = db.collection("users").document(currentUserId).collection("guests").document(guestId)
        batch.deleteDocument(guestRef)
        
        try await batch.commit()
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
    
    // MARK: - Helper Read Methods
    
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
    
    /// Fetches the original transaction to get details like location
    func fetchOriginalTransaction(userId: String, transactionId: String) async throws -> FirestoreModels.TransactionModel {
        let docRef = db.collection("users").document(userId).collection("transactions").document(transactionId)
        return try await docRef.getDocument(as: FirestoreModels.TransactionModel.self)
    }
    
    private var myGroupSplitsListener: ListenerRegistration?

    func listenToMyGroupSplits(groupId: String, currentUserId: String) {
         myGroupSplitsListener?.remove()
         // Logic is now integrated into listenToGroupBalances
         // This is kept empty or can be removed if unused in views.
    }
}
