import SwiftUI
import FirebaseFirestore
import MapKit

struct TransactionDetailView: View {
    @State private var transaction: FirestoreModels.TransactionModel
    @State private var showEditSheet = false
    @State private var showSplitSheet = false
    @State private var showFullMap = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository
    
    // Callback for saving changes
    var onSave: ((FirestoreModels.TransactionModel, TransactionFormData) -> Void)?
    
    // Repositories
    // Repositories moved to AppState
    @EnvironmentObject var transactionRepo: TransactionRepository
    @EnvironmentObject var requestRepo: RequestRepository
    @EnvironmentObject var friendRepo: FriendRepository
    @EnvironmentObject var budgetRepo: BudgetRepository
    
    // Error Handling
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Cached groupId for split re-editing (Fix #2)
    @State private var cachedGroupId: String? = nil
    
    // Deletion Alert
    @State private var showDeleteConfirmation = false
    
    init(transaction: FirestoreModels.TransactionModel, onSave: ((FirestoreModels.TransactionModel, TransactionFormData) -> Void)? = nil) {
        _transaction = State(initialValue: transaction)
        self.onSave = onSave
    }
    
    private var categoryIcon: String {
        budgetRepo.budgets.first(where: { $0.category.lowercased() == (transaction.subtitle?.lowercased() ?? "") })?.icon ?? "tag.fill"
    }
    
    private var categoryColor: String {
        budgetRepo.budgets.first(where: { $0.category.lowercased() == (transaction.subtitle?.lowercased() ?? "") })?.colorHex ?? transaction.colorHex ?? "#808080"
    }
    
    // Computed property for display logic
    private var displayAmount: Double {
        abs(transaction.amount)
    }
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
        VStack(spacing: 0) {
            // 1. Header (slim nav bar + title only)
            DetailHeaderView(
                title: "",
                subtitle: nil as String?,
                onBack: { dismiss() },
                onMenu: {
                    HapticManager.shared.light()
                    showEditSheet = true
                },
                backgroundColor: Color.backgroundPrimary,
                textColor: .primary,
                height: AppSize.headerHeightSlim,
                avatar: { EmptyView() },
                actions: { EmptyView() }
            )
            
            // 2. Scrollable Content
            ScrollView {
                VStack(spacing: AppSpacing.section) {
                    // Hero Section: Icon, Title, Note, Amount, Date
                    VStack(spacing: 8) {
                        Image(systemName: categoryIcon)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 80, height: 80)
                            .background(Color(hex: categoryColor))
                            .clipShape(Circle())
                        
                        Text(transaction.note?.isEmpty == false ? transaction.note! : transaction.title)
                            .font(AppTypography.titleDisplay)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text(transaction.subtitle ?? "Uncategorized")
                            .font(AppTypography.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Text(String(format: "$%.2f", displayAmount))
                            .font(AppTypography.prominentBalance)
                            .foregroundColor(.primary)
                        
                        Text(transaction.date.formatted(date: .long, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.element)
                    
                    // Section B: Split / Actions
                    if transaction.type != "income" {
                        Button(action: {
                            HapticManager.shared.light()
                            showSplitSheet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: transaction.splits?.isEmpty == false ? "person.2.fill" : "person.badge.plus.fill")
                                Text(transaction.splits?.isEmpty == false ? "View Split Details" : "Split this bill")
                            }
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(colorScheme == .dark ? Color.white : Color.black)
                            .clipShape(Capsule())
                        }
                    }

                    // Section C: Split Status Card
                    if transaction.type != "income", let splits = transaction.splits, !splits.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("SPLIT STATUS")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                                
                                VStack(spacing: 0) {
                                    ForEach(splits) { split in
                                        Button(action: { showSplitSheet = true }) {
                                            HStack(spacing: 12) {
                                                // Mini Avatar
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.primary.opacity(0.05))
                                                        .frame(width: 36, height: 36)
                                                    Text(String(split.name.prefix(1)).uppercased())
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(.primary)
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    HStack(spacing: 8) {
                                                        Text(split.name)
                                                            .font(.body)
                                                            .fontWeight(.medium)
                                                            .foregroundColor(.primary)
                                                        
                                                        if let friendId = split.friendId, userPremiumRepo.isPremium(userId: friendId) == true {
                                                            PremiumBadge(size: .small)
                                                        }
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text(String(format: "$%.2f", split.amount))
                                                        .font(.body.monospacedDigit())
                                                        .fontWeight(.semibold)
                                                    
                                                    if let status = split.status {
                                                        Text(status.capitalized)
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(status == "paid" ? .green : (status == "declined" ? .red : (status == "accepted" ? .blue : .orange)))
                                                    } else {
                                                        Text(split.isPaid ? "Paid" : "Pending")
                                                            .font(.caption2)
                                                            .foregroundColor(split.isPaid ? .green : .orange)
                                                    }
                                                }
                                                
                                                // Inline Paid Toggle
                                                Button(action: { toggleSplitPayment(split) }) {
                                                    Image(systemName: split.isPaid ? "checkmark.circle.fill" : "circle")
                                                        .font(.title3)
                                                        .foregroundColor(split.isPaid ? .green : .secondary.opacity(0.3))
                                                }
                                                
                                            }
                                            .padding(.vertical, 14)
                                            .padding(.horizontal, 16)
                                        }
                                        
                                        
                                        if split.id != splits.last?.id {
                                            Divider().padding(.horizontal, 16)
                                        }
                                    }
                                    
                                    // Net Cost Row
                                    HStack {
                                        Text("Net Cost")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        let reimbursed = splits.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
                                        Text(String(format: "$%.2f", abs(transaction.amount) - reimbursed))
                                            .font(.headline.monospacedDigit())
                                            .foregroundColor(.primary)
                                    }
                                    .padding(AppSpacing.element)
                                    .background(Color.primary.opacity(0.03))
                                }
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, AppSpacing.margin)
                        }
                        
                        // Section D: Details & Map Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("DETAILS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 0) {
                                // Map Header (Integrated into card)
                                if let lat = transaction.latitude, let lon = transaction.longitude {
                                    Map(initialPosition: .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), distance: 500))) {
                                        Marker(transaction.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                                    }
                                    .frame(height: 140)
                                    .overlay(
                                        Color.black.opacity(0.001)
                                            .onTapGesture { showFullMap = true }
                                    )
                                    
                                    Divider()
                                }
                                
                                TransactionDetailRow(icon: "tag", title: "Category", value: transaction.subtitle ?? "Uncategorized", color: Color(hex: categoryColor))
                                
                                if let originalAmount = transaction.originalAmount,
                                   let currencyCode = transaction.currencyCode {
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(icon: "banknote", title: "Original Amount", value: String(format: "%.2f %@", originalAmount, currencyCode), color: .blue)
                                    
                                    if let rate = transaction.exchangeRate {
                                        Divider().padding(.leading, 52)
                                        TransactionDetailRow(icon: "arrow.triangle.2.circlepath", title: "Exchange Rate", value: String(format: "1 %@ = %.2f %@", CurrencyManager.shared.mainCurrency, rate, currencyCode), color: .orange)
                                    }
                                }
                                
                                if let note = transaction.note, !note.isEmpty {
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(icon: "text.alignleft", title: "Notes", value: note, color: .secondary)
                                }
                                
                                Divider().padding(.leading, 52)
                                TransactionDetailRow(icon: "clock", title: "Created on", value: transaction.createdAt.formatted(date: .omitted, time: .shortened), color: .secondary)
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(AppRadius.medium)
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        
                        // Optional Location Name
                        if let locName = transaction.locationName, !locName.isEmpty {
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    Text(locName)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            .padding(.top, -AppSpacing.element)
                        }
                        
                        Spacer().frame(height: 20)
                        
                        // Delete Button
                        Button(action: {
                            checkAndDelete()
                        }) {
                            Text("Delete Transaction")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.functionalExpense.opacity(0.1))
                                .cornerRadius(AppRadius.large)
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        
                    Spacer().frame(height: 40)
                }
                .padding(.vertical)
            }
        }
        }
        .onAppear {
            // Refresh data to ensure sync when returning from other views
            Task {
                if let id = transaction.id, let fresh = try? await transactionRepo.fetchTransaction(id: id) {
                    await MainActor.run {
                        self.transaction = fresh
                    }
                }
                
                if let friendIds = transaction.splits?.compactMap({ $0.friendId }), !friendIds.isEmpty {
                    userPremiumRepo.prefetch(userIds: friendIds)
                }
                
                // Look up groupId from existing SplitRequest for re-editing context
                if cachedGroupId == nil,
                   let firstRequestId = transaction.splits?.compactMap({ $0.requestId }).first {
                    let reqDoc = try? await Firestore.firestore().collection("split_requests").document(firstRequestId).getDocument()
                    let groupId = reqDoc?.get("groupId") as? String
                    await MainActor.run {
                        self.cachedGroupId = groupId
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddTransactionView(transactionToEdit: transaction, onSave: { updatedTransaction in
                handleEdit(updatedTransaction)
            })
        }
        .fullScreenCover(isPresented: $showSplitSheet) {
            SplitConfigurationView(transactionAmount: abs(transaction.amount), existingSplits: transaction.splits ?? [], initialGroupId: cachedGroupId) { newSplits, groupId in
                updateSplits(newSplits, groupId: groupId)
            }
        }
        .sheet(isPresented: $showFullMap) {
            if let lat = transaction.latitude, let lon = transaction.longitude {
                FullScreenMapView(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), title: transaction.title)
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Delete Transaction", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteTransaction()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
    }
    
    // Logic remains same ...
    
    private func handleEdit(_ updatedTransaction: TransactionFormData) {
        let amount = Double(updatedTransaction.amount) ?? 0.0
        let oldAmount = transaction.amount
        var newModel = transaction
        newModel.title = updatedTransaction.title
        newModel.subtitle = updatedTransaction.subtitle
        newModel.amount = amount
        newModel.date = updatedTransaction.date
        newModel.icon = updatedTransaction.icon
        newModel.colorHex = updatedTransaction.color.toHex() ?? "#000000"
        newModel.note = updatedTransaction.notes
        newModel.type = amount < 0 ? "expense" : "income"
        newModel.latitude = updatedTransaction.latitude
        newModel.longitude = updatedTransaction.longitude
        newModel.locationName = updatedTransaction.locationName
        
        // Generate Edit History
        var edits: [FirestoreModels.EditRecord] = []
        let editorName = !appState.userName.isEmpty ? appState.userName : "You"
        
        if abs(amount - oldAmount) > 0.01 {
            edits.append(FirestoreModels.EditRecord(
                date: Date(),
                editorId: appState.currentUserId,
                editorName: editorName,
                field: "Amount",
                oldValue: String(format: "%.2f", oldAmount),
                newValue: String(format: "%.2f", amount)
            ))
        }
        
        if newModel.title != transaction.title {
            edits.append(FirestoreModels.EditRecord(
                date: Date(),
                editorId: appState.currentUserId,
                editorName: editorName,
                field: "Title",
                oldValue: transaction.title,
                newValue: newModel.title
            ))
        }
        
        if newModel.subtitle != transaction.subtitle {
            edits.append(FirestoreModels.EditRecord(
                date: Date(),
                editorId: appState.currentUserId,
                editorName: editorName,
                field: "Category",
                oldValue: transaction.subtitle ?? "None",
                newValue: newModel.subtitle ?? "None"
            ))
        }
        
        if newModel.note != transaction.note {
            // Only record if not just nil vs empty
            let oldNote = transaction.note ?? ""
            let newNote = newModel.note ?? ""
            if oldNote != newNote {
                edits.append(FirestoreModels.EditRecord(
                    date: Date(),
                    editorId: appState.currentUserId,
                    editorName: editorName,
                    field: "Note",
                    oldValue: oldNote.isEmpty ? "(Empty)" : oldNote,
                    newValue: newNote.isEmpty ? "(Empty)" : newNote
                ))
            }
        }
        
        // Append to existing history
        if !edits.isEmpty {
            var history = newModel.editHistory ?? []
            history.append(contentsOf: edits)
            newModel.editHistory = history
        }
        
        // Auto-recalculate splits proportionally if amount changed
        if let splits = newModel.splits, !splits.isEmpty, abs(abs(amount) - abs(oldAmount)) > 0.01 {
            let oldTotal = splits.reduce(0.0) { $0 + $1.amount }
            if oldTotal > 0 {
                let ratio = abs(amount) / (abs(oldAmount))
                var updatedSplits = splits
                for i in updatedSplits.indices {
                    updatedSplits[i].amount = (updatedSplits[i].amount * ratio * 100).rounded() / 100
                }
                newModel.splits = updatedSplits
                
                // Sync updated splits with Firestore (SplitRequests + GroupTransaction)
                self.transaction = newModel
                Task {
                    do {
                        // Derive groupId from existing SplitRequest (if any)
                        var groupId: String? = nil
                        if let firstRequestId = splits.compactMap({ $0.requestId }).first {
                            let reqDoc = try? await Firestore.firestore().collection("split_requests").document(firstRequestId).getDocument()
                            groupId = reqDoc?.get("groupId") as? String
                        }
                        
                        let finalTx = try await SocialTransactionManager.shared.createSocialTransaction(
                            transaction: newModel,
                            payerUid: newModel.userId,
                            payerName: (newModel.userId == appState.currentUserId) ? (!appState.userName.isEmpty ? appState.userName : (UserDefaults.standard.string(forKey: "user_name") ?? "Friend")) : (friendRepo.friends.first(where: { $0.id == newModel.userId })?.name ?? "Friend"),
                            groupId: groupId,
                            friendCache: friendRepo.friends,
                            groupCache: appState.groupRepo.groups
                        )
                        await MainActor.run {
                            self.transaction = finalTx
                        }
                    } catch {
                        print("DEBUG: Error syncing recalculated splits: \(error)")
                    }
                }
                onSave?(newModel, updatedTransaction)
                return
            }
        }
        
        self.transaction = newModel
        onSave?(transaction, updatedTransaction)
    }
    
    private func updateSplits(_ newSplits: [FirestoreModels.Split], groupId: String?) {
        var updatedTransaction = transaction
        updatedTransaction.splits = newSplits
        // Optimistic update
        self.transaction = updatedTransaction
        // Cache groupId for future re-edits
        if let groupId = groupId {
            self.cachedGroupId = groupId
        }
        
        Task {
            do {
                let finalTx = try await SocialTransactionManager.shared.createSocialTransaction(
                    transaction: updatedTransaction,
                    payerUid: updatedTransaction.userId,
                    payerName: (updatedTransaction.userId == appState.currentUserId) ? (!appState.userName.isEmpty ? appState.userName : (UserDefaults.standard.string(forKey: "user_name") ?? "Friend")) : (friendRepo.friends.first(where: { $0.id == updatedTransaction.userId })?.name ?? "Friend"),
                    groupId: groupId,
                    friendCache: friendRepo.friends,
                    groupCache: appState.groupRepo.groups
                )
                // Update with server-authoritative version (contains requestIds)
                await MainActor.run {
                    self.transaction = finalTx
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save splits: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    private func toggleSplitPayment(_ split: FirestoreModels.Split) {
        var targetUid: String?
        if let fid = split.friendId {
             targetUid = fid
        } else if let gid = split.guestId {
             targetUid = gid
        }
        
        print("DEBUG: Toggling split. GuestID: \(split.guestId ?? "nil"), FriendID: \(split.friendId ?? "nil"), TargetUID: \(targetUid ?? "nil")")
        
        guard let friendId = targetUid else {
            print("DEBUG: targetUid is nil, aborting")
            return
        }
        guard let transactionId = transaction.id else { return }
        
        HapticManager.shared.medium() // Feedback for toggling payment status
        
        // Optimistic UI update — toggle both isPaid AND status so the label
        // reflects the new state immediately, without waiting for Firestore.
        if let index = transaction.splits?.firstIndex(where: { $0.id == split.id }) {
            let currentlyPaid = transaction.splits![index].isPaid
            transaction.splits?[index].isPaid = !currentlyPaid
            // Mirror the expected post-toggle status string:
            // paid → accepted (reverted), anything else → paid
            transaction.splits?[index].status = currentlyPaid ? "accepted" : "paid"
        }
        
        Task {
            do {
                // 1. Fetch Request
                var request: FirestoreModels.SplitRequest?
                let db = Firestore.firestore()
                
                if let reqId = split.requestId {
                    let doc = try await db.collection("split_requests").document(reqId).getDocument()
                    request = try? doc.data(as: FirestoreModels.SplitRequest.self)
                }
                
                // Fallback if no requestId or not found
                if request == nil {
                    let snapshot = try await db.collection("split_requests")
                        .whereField("transactionId", isEqualTo: transactionId)
                        .whereField("toUid", isEqualTo: friendId)
                        .getDocuments()
                    request = try? snapshot.documents.first?.data(as: FirestoreModels.SplitRequest.self)
                }
                
                guard request != nil else {
                    print("DEBUGGING: Could not find split request for split: \(split.id). TransactionID: \(transactionId), ToUid: \(friendId)")
                    // Revert UI if failed
                    await MainActor.run {
                        if let index = transaction.splits?.firstIndex(where: { $0.id == split.id }) {
                            transaction.splits?[index].isPaid.toggle()
                        }
                    }
                    return
                }
                
                // 2. Toggle using Manager
                // Fetch FRESH split status from the request to be sure
                // Actually, manager takes the request object. 
                // We should check the REQUEST status.
                let currentStatus = request!.status
                
                if currentStatus == .accepted || currentStatus == .blocked_by_group {
                    // Mark as Paid
                     try await SocialTransactionManager.shared.markSplitAsPaid(request: request!, currentUserId: appState.currentUserId, currentUserName: appState.userName)
                } else if currentStatus == .paid {
                    // Unmark
                     try await SocialTransactionManager.shared.unmarkSplitAsPaid(request: request!, currentUserId: appState.currentUserId)
                }
                
                // Deliberately NOT re-fetching the transaction here.
                // The Cloud Function updates Firestore asynchronously; an immediate
                // fetchTransaction would return stale data and overwrite the
                // optimistic state we just applied above. The onAppear fetch
                // will sync the authoritative state the next time the view opens.
            } catch {
                print("Error toggling split payment: \(error)")
                // Revert UI — restore both isPaid and status
                await MainActor.run {
                    if let index = transaction.splits?.firstIndex(where: { $0.id == split.id }) {
                        let revertedPaid = !transaction.splits![index].isPaid
                        transaction.splits?[index].isPaid = revertedPaid
                        transaction.splits?[index].status = revertedPaid ? "paid" : "accepted"
                    }
                }
            }
        }
    }

    // MARK: - Deletion Logic
    
    private func checkAndDelete() {
        HapticManager.shared.warning()
        
        // 1. Check if it's a "Payment Received" transaction linked to a split
        if transaction.type == "income", let requestId = transaction.source, !requestId.isEmpty {
            // It's linked. Check status.
            Task {
                do {
                    let doc = try await Firestore.firestore().collection("split_requests").document(requestId).getDocument()
                    if let request = try? doc.data(as: FirestoreModels.SplitRequest.self) {
                        if request.status == .paid {
                            // Automatically revert paid split when deleted
                            await MainActor.run {
                                showDeleteConfirmation = true
                            }
                            return
                        }
                    }
                    // If not paid (e.g. pending/declined/nil/accepted), allow delete
                    await MainActor.run {
                        showDeleteConfirmation = true
                    }
                } catch {
                    // Error fetching request? Allow delete or fail safe?
                    // Fail safe: Block if we can't verify
                    await MainActor.run {
                        errorMessage = "Could not verify split status. Please try again."
                        showErrorAlert = true
                    }
                }
            }
        } else {
            // Normal transaction
            showDeleteConfirmation = true
        }
    }
    
    private func deleteTransaction() {
        Task {
            do {
                // Revert linked split if needed (for pending/orphaned ones)
                // Note: We use the manager function but ignore result since we checked blocking above
                let _ = await SocialTransactionManager.shared.revertLinkedSplitIfNeeded(transaction: transaction, currentUserId: appState.currentUserId)
                if let splits = transaction.splits, !splits.isEmpty {
                    if transaction.id != nil {
                        await MainActor.run {
                            transactionRepo.optimisticDelete(transaction: transaction)
                        }
                    }
                    try await SocialTransactionManager.shared.deleteSocialTransaction(transaction: transaction)
                } else {
                    if let id = transaction.id {
                        try await transactionRepo.deleteTransaction(id: id)
                    }
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete transaction: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}

// TransactionDetailRow is in Views/Components/TransactionDetailRow.swift
