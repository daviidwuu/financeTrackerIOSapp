import SwiftUI
import FirebaseFirestore

struct RecurringTransactionDetailView: View {
    @State private var transaction: FirestoreModels.RecurringTransaction
    @State private var showEditSheet = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var transactionRepo: TransactionRepository
    @EnvironmentObject var budgetRepo: BudgetRepository
    
    /// Resolve icon from stored value, or look up from budget category
    private var resolvedIcon: String {
        if let icon = transaction.icon { return icon }
        if let budget = matchedBudget { return budget.icon }
        return "arrow.2.squarepath"
    }
    
    /// Resolve color from stored value, or look up from budget category
    private var resolvedColorHex: String {
        if let color = transaction.colorHex { return color }
        if let budget = matchedBudget { return budget.colorHex }
        return "#8E8E93"
    }
    
    /// Find the matching budget by categoryId or name
    private var matchedBudget: FirestoreModels.CategoryBudget? {
        if let catId = transaction.categoryId {
            return budgetRepo.budgets.first(where: { $0.id == catId })
        }
        return budgetRepo.budgets.first(where: { $0.category.lowercased() == transaction.name.lowercased() })
    }
    
    // Error Handling
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Missed Occurrences
    @State private var missedDates: [Date] = []
    @State private var isProcessingDates: Set<Date> = []
    
    // Callback for saving changes
    var onSave: ((FirestoreModels.RecurringTransaction, RecurringTransactionFormData) -> Void)?
    var onDelete: (() -> Void)?
    
    init(transaction: FirestoreModels.RecurringTransaction, onSave: ((FirestoreModels.RecurringTransaction, RecurringTransactionFormData) -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        _transaction = State(initialValue: transaction)
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
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
                
                ScrollView {
                    VStack(spacing: AppSpacing.section) {
                        // Hero Section
                        VStack(spacing: 8) {
                            Image(systemName: resolvedIcon)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 80, height: 80)
                                .background(Color(hex: resolvedColorHex))
                                .clipShape(Circle())
                            
                            Text(transaction.name)
                                .font(AppTypography.titleDisplay)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text(transaction.frequency)
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(hex: resolvedColorHex).opacity(0.1))
                                .cornerRadius(AppRadius.small)
                            
                            Text(String(format: "$%.2f", transaction.amount))
                                .font(AppTypography.prominentBalance)
                                .foregroundColor(.primary)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.element)
                        
                        // Action Banner
                        if !missedDates.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Missed Occurrences")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(missedDates.count)")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .clipShape(Capsule())
                                }
                                
                                Text("It looks like some expected logs are missing. Check the boxes below to manually log them.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 0) {
                                    ForEach(missedDates, id: \.self) { date in
                                        HStack {
                                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.body)
                                            
                                            Spacer()
                                            
                                            let isProcessing = isProcessingDates.contains(date)
                                            Button(action: { HapticManager.shared.light(); 
                                                if !isProcessing {
                                                    logMissedOccurrence(for: date)
                                                }
                                            }) {
                                                if isProcessing {
                                                    ProgressView()
                                                        .frame(width: 24, height: 24)
                                                } else {
                                                    Image(systemName: "square")
                                                        .font(.title3)
                                                        .foregroundColor(.blue)
                                                }
                                            }
                                            .disabled(isProcessing)
                                        }
                                        .padding(.vertical, 12)
                                        
                                        if date != missedDates.last {
                                            Divider()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .background(Color.backgroundPrimary)
                                .cornerRadius(AppRadius.small)
                                .padding(.top, 8)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.05))
                            .cornerRadius(AppRadius.medium)
                            .padding(.horizontal, AppSpacing.margin)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                                    .padding(.horizontal, AppSpacing.margin)
                            )
                        }
                        
                        // Details Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("DETAILS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 0) {
                                TransactionDetailRow(icon: "calendar", title: "Start Date", value: transaction.startDate.formatted(date: .abbreviated, time: .omitted), color: .blue)
                                
                                if let lastProcessed = transaction.lastProcessedDate {
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(icon: "clock.arrow.2.circlepath", title: "Last Automated Run", value: lastProcessed.formatted(date: .abbreviated, time: .omitted), color: .purple)
                                }
                                
                                if let note = transaction.note, !note.isEmpty {
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(icon: "text.alignleft", title: "Notes", value: note, color: .secondary)
                                }
                                
                                Divider().padding(.leading, 52)
                                TransactionDetailRow(icon: "clock", title: "Created on", value: transaction.createdAt.formatted(date: .omitted, time: .shortened), color: .secondary)
                            }
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        
                        Spacer().frame(height: 20)
                        
                        // Delete Button
                        Button(action: {
                            HapticManager.shared.heavy()
                            onDelete?()
                            dismiss()
                        }) {
                            Text("Delete Recurring Transaction")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.functionalExpense.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        
                        Spacer().frame(height: 40)
                    }
                }
            }
        }
        .onAppear {
            calculateMissedDates()
        }
        .onChange(of: transactionRepo.allTransactions.count) { _, _ in
            // Recalculate if transactions change (e.g., after logging a missed one)
            calculateMissedDates()
        }
        .sheet(isPresented: $showEditSheet) {
            AddRecurringTransactionView(recurringToEdit: transaction, onSave: { updatedForm in
                handleEdit(updatedForm)
            })
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { HapticManager.shared.light();  }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func calculateMissedDates() {
        // Find missed dates using the helper function
        let dates = WalletLogic.calculateMissedOccurrences(
            recurring: transaction,
            loggedTransactions: transactionRepo.allTransactions
        )
        
        withAnimation {
            self.missedDates = dates
        }
    }
    
    private func logMissedOccurrence(for date: Date) {
        HapticManager.shared.light()
        isProcessingDates.insert(date)
        
        let type = transaction.type ?? "expense"
        let finalAmount = (type == "income") ? abs(transaction.amount) : -abs(transaction.amount)
        
        let newLog = FirestoreModels.TransactionModel(
            userId: appState.currentUserId,
            title: transaction.name,
            categoryId: transaction.categoryId,
            amount: finalAmount,
            date: date,
            type: type,
            createdAt: Date(),
            note: "Recurring: \(transaction.frequency)" + (transaction.note?.isEmpty == false ? " - \(transaction.note!)" : "")
        )
        
        Task {
            do {
                try await transactionRepo.addTransaction(newLog)
                await MainActor.run {
                    HapticManager.shared.success()
                    isProcessingDates.remove(date)
                    // The onChange observer will re-calculate missed dates since transactions changed
                }
            } catch {
                await MainActor.run {
                    isProcessingDates.remove(date)
                    self.errorMessage = "Failed to log past occurrence: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }
    
    private func handleEdit(_ updatedForm: RecurringTransactionFormData) {
        var newModel = transaction
        newModel.name = updatedForm.name
        newModel.amount = updatedForm.amount
        newModel.frequency = updatedForm.frequency
        newModel.startDate = updatedForm.startDate
        newModel.icon = updatedForm.icon
        newModel.colorHex = updatedForm.color.toHex() ?? "#000000"
        newModel.note = updatedForm.notes
        newModel.type = updatedForm.type
        
        self.transaction = newModel
        onSave?(newModel, updatedForm)
    }
}
