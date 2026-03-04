import SwiftUI
import FirebaseFirestore

struct DailyTransactionSheet: View {
    let date: Date
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var transactionRepo: TransactionRepository
    @EnvironmentObject var budgetRepo: BudgetRepository
    
    @State private var selectedTransaction: FirestoreModels.TransactionModel?
    @State private var transactionToEdit: FirestoreModels.TransactionModel?
    @State private var showDeleteConfirmation = false
    @State private var transactionToDelete: FirestoreModels.TransactionModel?
    @State private var errorState = ErrorState()
    @State private var undoState = UndoState()
    
    var dailyTransactions: [FirestoreModels.TransactionModel] {
        let calendar = Calendar.current
        return transactionRepo.calendarTransactions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()
                
                List {
                    ScrollOffsetTracker()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    
                    Color.clear.frame(height: 60)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        
                    if dailyTransactions.isEmpty {
                        EmptyStateView(
                            icon: "tray.fill",
                            title: "No Transactions",
                            message: "There are no transactions for this day.",
                            actionTitle: "Got it",
                            action: { dismiss() }
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(dailyTransactions, id: \.id) { transaction in
                            TransactionRow(transaction: transaction)
                                .id(transaction.id)
                                .background(Color.cardBackground)
                                .cornerRadius(AppRadius.medium)
                                .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .padding(.bottom, AppSpacing.compact)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        HapticManager.shared.heavy()
                                        checkAndDelete(transaction)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    if !transaction.isReimbursementIncome(categories: budgetRepo.budgets) {
                                        Button {
                                            HapticManager.shared.medium()
                                            transactionToEdit = transaction
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                }
                                .onTapGesture {
                                    HapticManager.shared.light()
                                    selectedTransaction = transaction
                                }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.top, 16)
            }
            .overlayHeader(.navigation(
                title: dateString,
                onBack: { dismiss() },
                backIcon: "xmark"
            ))
            .navigationBarHidden(true)
            .errorBanner(errorState)
            .undoableBanner(undoState)
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction) { original, updated in
                    updateTransaction(original, with: updated)
                }
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $transactionToEdit) { transaction in
                AddTransactionView(transactionToEdit: transaction, onSave: { updatedTransaction in
                    updateTransaction(transaction, with: updatedTransaction)
                })
            }
            .alert("Delete Transaction", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) { 
                    HapticManager.shared.light()
                    if let tx = transactionToDelete {
                        deleteTransaction(tx)
                    }
                }
                Button("Cancel", role: .cancel) { 
                    HapticManager.shared.light()
                    transactionToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this transaction? This action cannot be undone.")
            }
        }
    }
    
    private func updateTransaction(_ entity: FirestoreModels.TransactionModel, with transaction: TransactionFormData) {
        Task {
            do {
                let amount = CurrencyInput.parseOrZero(transaction.amount)
                var updatedTransaction = entity
                updatedTransaction.title = transaction.title
                updatedTransaction.categoryId = transaction.categoryId
                updatedTransaction.amount = amount
                updatedTransaction.date = transaction.date
                updatedTransaction.note = transaction.notes
                updatedTransaction.type = amount < 0 ? "expense" : "income"
                updatedTransaction.latitude = transaction.latitude
                updatedTransaction.longitude = transaction.longitude
                updatedTransaction.locationName = transaction.locationName
                
                try await transactionRepo.updateTransaction(updatedTransaction)
                
                if let splits = updatedTransaction.splits, !splits.isEmpty {
                    var groupId: String? = nil
                    if let firstRequestId = splits.compactMap({ $0.requestId }).first {
                        let reqDoc = try? await Firestore.firestore().collection("split_requests").document(firstRequestId).getDocument()
                        groupId = reqDoc?.get("groupId") as? String
                    }
                    
                    try await SocialTransactionManager.shared.createSocialTransaction(
                        transaction: updatedTransaction,
                        payerUid: appState.currentUserId,
                        payerName: appState.userName,
                        groupId: groupId,
                        friendCache: appState.friendRepo.friends,
                        groupCache: appState.groupRepo.groups
                    )
                }
            } catch {
                DebugLogger.log("Failed to update transaction: \(error)")
                errorState.show("Failed to update transaction")
            }
        }
    }
    
    private func checkAndDelete(_ transaction: FirestoreModels.TransactionModel) {
        if transaction.type == "income", let requestId = transaction.source, !requestId.isEmpty, requestId != "recurring", !requestId.hasPrefix("recurring_") {
            Task {
                do {
                    let doc = try await Firestore.firestore().collection("split_requests").document(requestId).getDocument()
                    if let request = try? doc.data(as: FirestoreModels.SplitRequest.self) {
                        if request.status == .paid {
                            await MainActor.run {
                                errorState.show("This transaction verifies a paid split. Please unmark the split as paid if you wish to undo this payment.")
                            }
                            return
                        }
                    }
                    await MainActor.run {
                        transactionToDelete = transaction
                        showDeleteConfirmation = true
                    }
                } catch {
                    await MainActor.run {
                        errorState.show("Could not verify split status. Please try again.")
                    }
                }
            }
        } else {
            transactionToDelete = transaction
            showDeleteConfirmation = true
        }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.TransactionModel) {
        guard let id = transaction.id else { return }
        
        withAnimation {
            transactionRepo.optimisticDelete(transaction: transaction)
        }
        
        undoState.schedule(
            label: "Transaction deleted",
            onUndo: {
                withAnimation {
                    transactionRepo.undoDelete(id: id)
                }
            },
            onConfirm: {
                Task {
                    do {
                        let _ = await SocialTransactionManager.shared.revertLinkedSplitIfNeeded(transaction: transaction, currentUserId: appState.currentUserId)
                        
                        if let splits = transaction.splits, !splits.isEmpty {
                            try await SocialTransactionManager.shared.deleteSocialTransaction(transaction: transaction)
                        } else {
                            try await transactionRepo.deleteTransaction(id: id)
                        }
                    } catch {
                        DebugLogger.log("Failed to delete transaction: \(error)")
                        await MainActor.run {
                            withAnimation {
                                transactionRepo.undoDelete(id: id)
                            }
                            errorState.show("Failed to delete transaction")
                        }
                    }
                }
            }
        )
    }
}
