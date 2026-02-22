import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class SocialRepository: ObservableObject {
    private let db = Firestore.firestore()
    
    // FIX #20: Clean up all listeners on deallocation
    deinit {
        globalSentListener?.remove()
        globalReceivedListener?.remove()
        friendTransactionsListener1?.remove()
        friendTransactionsListener2?.remove()
        groupBalancesListener?.remove()
        myGroupSplitsListener?.remove()
    }
    
    // MARK: - Leaderboard Data
    struct LeaderboardEntry: Identifiable {
        let id: String
        let name: String
        let points: Int
    }

    @Published var friendBalances: [String: Double] = [:] // Real-time balance
    @Published var groupBalances: [String: [String: Double]] = [:] // FIX 1.3: currency → (memberId → balance)
    
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
                .filter { req in
                    guard let hidden = req.hiddenFor else { return true }
                    return !hidden.contains(currentUserId)
                }
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
                .filter { req in
                    guard let hidden = req.hiddenFor else { return true }
                    return !hidden.contains(currentUserId)
                }
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
            
            let allRequests = (sentRequests + receivedRequests)
                .filter { req in
                    // Issue #7: Exclude splits hidden by current user
                    guard let hidden = req.hiddenFor else { return true }
                    return !hidden.contains(currentUserId)
                }
            
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
                    source: req.transactionId, // Pass Original Transaction ID
                    originalAmount: req.originalTotalAmount // ✅ Pass the original full amount
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
            guard let self = self else { return }
            if let error = error {
                print("Error listening to sent requests: \(error)")
                DispatchQueue.main.async { self.errorMessage = "Error fetching sent requests: \(error.localizedDescription)" }
                return
            }
            
            sentRequests = snapshot?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
            updateBlock()
        }
        
        // Listener 2 (Received)
        friendTransactionsListener2 = q2.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error listening to received requests: \(error)")
                DispatchQueue.main.async { self.errorMessage = "Error fetching received requests: \(error.localizedDescription)" }
                return
            }
            
            receivedRequests = snapshot?.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) } ?? []
            updateBlock()
        }
    }
    
    // MARK: - Balances
    
    /// Calculates the net balance with a friend, grouped by currency
    /// FIX #7: Replaced silent `try?` with proper error handling
    func calculateFriendBalance(currentUserId: String, friendId: String) async -> [String: Double] {
        let requestsRef = db.collection("split_requests")
        
        do {
            // 1. You paid/requested (They owe you) - Status: Pending or Accepted
            let q1 = try await requestsRef
                .whereField("fromUid", isEqualTo: currentUserId)
                .whereField("toUid", isEqualTo: friendId)
                .getDocuments()
            
            // 2. They paid/requested (You owe them)
            let q2 = try await requestsRef
                .whereField("fromUid", isEqualTo: friendId)
                .whereField("toUid", isEqualTo: currentUserId)
                .getDocuments()
                
            let sent = q1.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) }
            let received = q2.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) }
            
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
        } catch {
            DebugLogger.log("Error calculating friend balance: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to calculate balance: \(error.localizedDescription)"
            }
            return [:]
        }
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
                    .filter { req in
                        guard let hidden = req.hiddenFor else { return true }
                        return !hidden.contains(currentUserId)
                    }
                
                // FIX 1.3: Group balances by currency
                let mainCurrency = CurrencyManager.shared.mainCurrency
                var balancesByCurrency: [String: [String: Double]] = [:]
                
                for req in activeRequests {
                    let currency = req.currency ?? mainCurrency
                    balancesByCurrency[currency, default: [:]][req.fromUid, default: 0] += req.amount
                    balancesByCurrency[currency, default: [:]][req.toUid, default: 0] -= req.amount
                }
                
                // Filter for "My Pending Splits" (Real-time)
                let mySplits = activeRequests.filter { req in
                    return req.status == .pending && (req.toUid == currentUserId || req.fromUid == currentUserId)
                }.sorted(by: { $0.createdAt > $1.createdAt })
                
                DispatchQueue.main.async {
                    self.groupBalances = balancesByCurrency
                    self.myPendingGroupSplits = mySplits
                }
            }
    }
    
    /// Calculates balances for all members in a group (One-shot) — FIX 1.3: Currency-aware
    func calculateGroupBalances(groupId: String, currentUserId: String) async -> [String: [String: Double]] {
        let requestsRef = db.collection("split_requests")
        
        do {
            let snapshot = try await requestsRef
                .whereField("groupId", isEqualTo: groupId)
                .getDocuments()
                
            let activeRequests = snapshot.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) }
                .filter { $0.status == .pending || $0.status == .accepted }
            
            let mainCurrency = CurrencyManager.shared.mainCurrency
            var balancesByCurrency: [String: [String: Double]] = [:]
            
            for req in activeRequests {
                let currency = req.currency ?? mainCurrency
                balancesByCurrency[currency, default: [:]][req.fromUid, default: 0] += req.amount
                balancesByCurrency[currency, default: [:]][req.toUid, default: 0] -= req.amount
            }
            
            return balancesByCurrency
        } catch {
            print("Error calculating group balances: \(error)")
            return [:]
        }
    }
    
    // Derived Debt Instructions (Helper)
    func getDebtInstructions() -> [DebtInstruction] {
        // FIX 1.3: Use multi-currency resolution
        return DebtCalculator.shared.calculateMultiCurrencyResolution(balancesByCurrency: groupBalances)
    }
    
    // MARK: - Actions
    
    func sendNudge(friendId: String) async throws {
        // In a real app, this would send a push notification
        // For now, we'll just simulate a network call
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    
    func deleteFriendTransaction(transactionId: String) async throws {
        // FIX 2.1: Route through proper cascade instead of raw delete.
        // The old code directly deleted the split_requests doc without updating
        // the source transaction's splits array, leaving orphaned requestId references.
        let doc = try await db.collection("split_requests").document(transactionId).getDocument()
        guard let request = try? doc.data(as: FirestoreModels.SplitRequest.self) else {
            // Fallback: if we can't decode, still remove from local list
            await MainActor.run { self.friendTransactions.removeAll { $0.id == transactionId } }
            return
        }
        try await SocialTransactionManager.shared.resolveSplitRequestAction(request: request)
        
        // Optimistically remove from local list
        await MainActor.run {
            self.friendTransactions.removeAll { $0.id == transactionId }
        }
    }
    
    func deleteGroupTransaction(transactionId: String, groupId: String) async throws {
        // FIX 2.2: The old code queried split_requests by transactionId == groupTransactionId,
        // but SplitRequest.transactionId stores the ORIGINAL user transaction ID, not the group
        // transaction ID. This query always returned 0 results, so splits were never cleaned up.
        // Now we fetch the group transaction to get originalTransactionId and use proper cascade.
        let groupTxDoc = try await db.collection("groups").document(groupId)
            .collection("transactions").document(transactionId).getDocument()
        
        if let groupTx = try? groupTxDoc.data(as: FirestoreModels.GroupTransaction.self) {
            // Use the full cascade manager which handles:
            // - Archiving the group transaction
            // - Deleting associated split requests
            // - Cleaning up income transactions from paid splits
            // - Deleting the original user transaction (if current user is payer)
            try await SocialTransactionManager.shared.deleteSocialTransaction(
                groupTransaction: groupTx, groupId: groupId)
        } else {
            // Fallback: just delete the group transaction doc if we can't decode it
            try await db.collection("groups").document(groupId)
                .collection("transactions").document(transactionId).delete()
        }
        
        // Optimistically remove from local list
        await MainActor.run {
            self.groupTransactions.removeAll { $0.id == transactionId }
        }
    }
    
    func calculateDebtResolution(balances: [String: [String: Double]]) -> [DebtInstruction] {
        // FIX 1.3: Use multi-currency resolution
        return DebtCalculator.shared.calculateMultiCurrencyResolution(balancesByCurrency: balances)
    }
    
    // FIX #6: settleUp has been removed from SocialRepository.
    // Use SocialTransactionManager.settleUp instead, which is the correct, complete implementation
    // that creates the payer-side expense transaction, settlement split request, and group feed item.
    
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
        self.errorMessage = nil
        
        var allIds = friends.compactMap { $0.id }
        allIds.append(currentUser.id)
        // Remove duplicates just in case
        allIds = Array(Set(allIds))
        
        Task {
            var entries: [LeaderboardEntry] = []
            
            // Chunk ids into groups of 30 (Firestore limit for 'in' query is 30)
            let chunkSize = 30
            let chunks = stride(from: 0, to: allIds.count, by: chunkSize).map {
                Array(allIds[$0..<min($0 + chunkSize, allIds.count)])
            }
            
            for chunk in chunks {
                do {
                    let snapshot = try await db.collection("users")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    
                    let chunkEntries = snapshot.documents.compactMap { doc -> LeaderboardEntry? in
                        let data = doc.data()
                        let name = data["name"] as? String ?? "Unknown"
                        let points = data["points"] as? Int ?? 0
                        return LeaderboardEntry(id: doc.documentID, name: name, points: points)
                    }
                    entries.append(contentsOf: chunkEntries)
                } catch {
                    print("Error fetching leaderboard chunk: \(error)")
                    // We continue fetching other chunks even if one fails
                }
            }
            
            // Sort Descending
            let sorted = entries.sorted { $0.points > $1.points }
            
            await MainActor.run {
                self.leaderboardData = sorted
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helper Read Methods
    
    func fetchSplitsForTransaction(transactionId: String, groupId: String? = nil) async throws -> [FirestoreModels.SplitRequest] {
        var query: Query = db.collection("split_requests")
            .whereField("transactionId", isEqualTo: transactionId)
            
        if let groupId = groupId {
            query = query.whereField("groupId", isEqualTo: groupId)
        }
        
        let snapshot = try await query.getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: FirestoreModels.SplitRequest.self) }
    }
    
    /// OPTIMISTIC UPDATE: Removes a transaction from the local list immediately
    func removeLocalTransaction(id: String) {
        self.friendTransactions.removeAll { $0.id == id }
    }
    
    /// Fetches the original transaction to get details like location
    func fetchOriginalTransaction(userId: String, transactionId: String) async throws -> FirestoreModels.TransactionModel? {
        // Security Check: Users can only read their own transactions from the private collection
        guard let currentUserId = Auth.auth().currentUser?.uid else { return nil }
        
        if userId != currentUserId {
            print("⚠️ Cannot fetch original transaction from another user's private collection. (Privacy Restricted)")
            return nil
        }
        
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
