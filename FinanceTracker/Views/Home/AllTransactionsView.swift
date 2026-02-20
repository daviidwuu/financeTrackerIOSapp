import SwiftUI
import FirebaseFirestore

struct AllTransactionsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
    @ObservedObject var transactionRepo: TransactionRepository
    @ObservedObject var budgetRepo: BudgetRepository
    
    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedMonth: Date = Date()
    @State private var selectedDate: Date? = nil // Specific day filter
    @State private var selectedType: String = "All" // "All", "Income", "Expense"
    @State private var sortBy: String = "Date" // "Date", "Amount", "Category"
    @State private var sortAscending: Bool = false // false = newest/highest first
    
    @State private var selectedTransaction: FirestoreModels.TransactionModel?
    @State private var transactionToEdit: FirestoreModels.TransactionModel?
    @State private var errorState = ErrorState()
    @State private var undoState = UndoState()
    
    // Deletion Alert
    @State private var showDeleteConfirmation = false
    @State private var transactionToDelete: FirestoreModels.TransactionModel?
    
    init(transactionRepo: TransactionRepository, budgetRepo: BudgetRepository, initialDate: Date? = nil) {
        self.transactionRepo = transactionRepo
        self.budgetRepo = budgetRepo
        _selectedDate = State(initialValue: initialDate)
        // If initialDate is provided, set selectedMonth to that date so repo fetches correctly
        if let initial = initialDate {
            _selectedMonth = State(initialValue: initial)
        }
    }
    
    var filteredTransactions: [FirestoreModels.TransactionModel] {
        transactionRepo.transactions.filter { transaction in
            // Month filter is now handled by Repository, but we keep this check for consistency
            // in case repo returns data from a transition period or user changes filter rapidly.
            let matchesMonth: Bool
            if let date = selectedDate {
                matchesMonth = Calendar.current.isDate(transaction.date, inSameDayAs: date)
            } else {
                matchesMonth = Calendar.current.isDate(transaction.date, equalTo: selectedMonth, toGranularity: .month)
            }
            
            // Category filter
            let matchesCategory = selectedCategory == nil || 
                                 transaction.subtitle == selectedCategory
            
            // Type filter
            let matchesType = selectedType == "All" ||
                            (selectedType == "Income" && transaction.type == "income") ||
                            (selectedType == "Expense" && transaction.type == "expense")
            
            // Search filter
            let matchesSearch = searchText.isEmpty || 
                               transaction.title.localizedCaseInsensitiveContains(searchText) ||
                               (transaction.note?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            return matchesMonth && matchesCategory && matchesType && matchesSearch
        }
    }
    
    var sortedTransactions: [FirestoreModels.TransactionModel] {
        filteredTransactions.sorted { t1, t2 in
            switch sortBy {
            case "Amount":
                return sortAscending ? abs(t1.amount) < abs(t2.amount) : abs(t1.amount) > abs(t2.amount)
            case "Category":
                return sortAscending ? t1.subtitle ?? "" < t2.subtitle ?? "" : t1.subtitle ?? "" > t2.subtitle ?? ""
            default: // Date
                return sortAscending ? t1.date < t2.date : t1.date > t2.date
            }
        }
    }
    
    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedType != "All" || !searchText.isEmpty || selectedDate != nil
    }
    
    var transactionStats: (count: Int, total: Double, average: Double) {
        let count = filteredTransactions.count
        let total = filteredTransactions.reduce(0) { $0 + $1.amount }
        let average = count > 0 ? total / Double(count) : 0
        return (count, total, average)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                .ignoresSafeArea()
            
            // Main Content
             List {
                 // Spacer for fixed Navigation Bar
                 Color.clear.frame(height: 60)
                     .listRowSeparator(.hidden)
                     .listRowBackground(Color.clear)
                 
                 // Search & Filters Header
                 VStack(spacing: 16) {
                     // Search Bar
                    HStack(alignment: .center) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                        TextField("Search transactions...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                    .padding(.horizontal, AppSpacing.margin)
                    
                    // Type Filter Segmented Control
                    Picker("Type", selection: $selectedType) {
                        Text("All").tag("All")
                        Text("Income").tag("Income")
                        Text("Expense").tag("Expense")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.margin)
                    
                    // Category & Month Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Category Filter
                            Menu {
                                Button("All Categories") {
                                    selectedCategory = nil
                                }
                                
                                Divider()
                                
                                ForEach(budgetRepo.budgets.sorted(by: { $0.category < $1.category })) { budget in
                                    Button(action: {
                                        selectedCategory = budget.category
                                    }) {
                                        HStack {
                                            Image(systemName: budget.icon)
                                            Text(budget.category)
                                            if selectedCategory == budget.category {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 14))
                                    Text(selectedCategory ?? "Category")
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(AppRadius.small)
                            }
                            
                            // Month Filter
                            Menu {
                                ForEach(0..<12, id: \.self) { offset in
                                    let date = Calendar.current.date(byAdding: .month, value: -offset, to: Date())!
                                    Button(action: {
                                        selectedMonth = date
                                    }) {
                                        HStack {
                                            Text(monthYearString(from: date))
                                            if Calendar.current.isDate(selectedMonth, equalTo: date, toGranularity: .month) {
                                                Spacer()
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14))
                                    Text(monthYearString(from: selectedMonth))
                                        .font(.subheadline)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(AppRadius.small)
                            }
                            
                            // Date Filter (Specific Day)
                            if selectedDate == nil {
                                Menu {
                                    Button("Today") {
                                        selectedDate = Date()
                                    }
                                    Button("Yesterday") {
                                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                                    }
                                    Divider()
                                    // Pick from current month
                                    ForEach(0..<31, id: \.self) { offset in
                                        if let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()),
                                           Calendar.current.isDate(date, equalTo: selectedMonth, toGranularity: .month) {
                                            Button(action: {
                                                selectedDate = date
                                            }) {
                                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "calendar.day.timeline.left")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                        .frame(width: 36, height: 36)
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .cornerRadius(AppRadius.small)
                                }
                            }
                            
                            // Export Button
                            if !filteredTransactions.isEmpty {
                                ShareLink(item: generateCSV(), preview: SharePreview("Transactions Export", image: Image(systemName: "doc.text"))) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                        .frame(width: 36, height: 36)
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .cornerRadius(AppRadius.small)
                                }
                            }
                            
                            // Sort Menu
                            Menu {
                                Button(action: { sortBy = "Date"; sortAscending = false }) {
                                    Label("Newest First", systemImage: sortBy == "Date" && !sortAscending ? "checkmark" : "")
                                }
                                Button(action: { sortBy = "Date"; sortAscending = true }) {
                                    Label("Oldest First", systemImage: sortBy == "Date" && sortAscending ? "checkmark" : "")
                                }
                                Divider()
                                Button(action: { sortBy = "Amount"; sortAscending = false }) {
                                    Label("Highest Amount", systemImage: sortBy == "Amount" && !sortAscending ? "checkmark" : "")
                                }
                                Button(action: { sortBy = "Amount"; sortAscending = true }) {
                                    Label("Lowest Amount", systemImage: sortBy == "Amount" && sortAscending ? "checkmark" : "")
                                }
                                Divider()
                                Button(action: { sortBy = "Category"; sortAscending = true }) {
                                    Label("Category A-Z", systemImage: sortBy == "Category" && sortAscending ? "checkmark" : "")
                                }
                                Button(action: { sortBy = "Category"; sortAscending = false }) {
                                    Label("Category Z-A", systemImage: sortBy == "Category" && !sortAscending ? "checkmark" : "")
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(AppRadius.small)
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                    }
                    
                    // Active Filter Chips
                    if hasActiveFilters {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                if let category = selectedCategory {
                                    FilterChip(title: category, icon: "folder") {
                                        selectedCategory = nil
                                    }
                                }
                                if selectedType != "All" {
                                    FilterChip(title: selectedType, icon: selectedType == "Income" ? "arrow.down.circle" : "arrow.up.circle") {
                                        selectedType = "All"
                                    }
                                }
                                if !searchText.isEmpty {
                                    FilterChip(title: "Search: \(searchText)", icon: "magnifyingglass") {
                                        searchText = ""
                                    }
                                }
                                if let date = selectedDate {
                                    FilterChip(title: date.formatted(date: .abbreviated, time: .omitted), icon: "calendar") {
                                        selectedDate = nil
                                    }
                                }
                            }
                            .padding(.horizontal, AppSpacing.margin)
                        }
                    }
                    
                    // Summary Stats
                    HStack(spacing: 16) {
                        StatCard(title: "Total", value: "$\(Int(abs(transactionStats.total)))", icon: "dollarsign.circle")
                        StatCard(title: "Count", value: "\(transactionStats.count)", icon: "number.circle")
                        StatCard(title: "Avg", value: "$\(Int(abs(transactionStats.average)))", icon: "chart.bar")
                    }
                    .padding(.horizontal, AppSpacing.margin)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets()) // Remove default padding
                .padding(.bottom, 8)
                
                // Transaction List
                if filteredTransactions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No transactions found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try adjusting your filters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(sortedTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
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
                                Button {
                                    HapticManager.shared.medium()
                                    transactionToEdit = transaction
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
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
            // Fetch transactions when month changes
            .onChange(of: selectedMonth) { _, newMonth in
                transactionRepo.startListening(userId: appState.currentUserId, month: newMonth)
            }
            .onAppear {
                // Initial fetch for the selected month
                transactionRepo.startListening(userId: appState.currentUserId, month: selectedMonth)
            }
            .onDisappear {
                // Reset to default (latest 50) when leaving this view
                transactionRepo.startListening(userId: appState.currentUserId, month: nil, showLoading: false)
            }
            
            // Fixed Navigation Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 44, height: 44)
                        .background((colorScheme == .dark ? Color.white : Color.black).opacity(0.05))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Transactions")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Spacer()
                
                // Placeholder to balance layout
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, AppSpacing.margin + AppSpacing.compact)
            .padding(.top, 16)
            
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
                    if let tx = transactionToDelete {
                        deleteTransaction(tx)
                    }
                }
                Button("Cancel", role: .cancel) { 
                    transactionToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this transaction? This action cannot be undone.")
            }
        }
    }
    
    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
    
    private func updateTransaction(_ entity: FirestoreModels.TransactionModel, with transaction: TransactionFormData) {
        Task {
            do {
                let amount = CurrencyInput.parseOrZero(transaction.amount)
                var updatedTransaction = entity
                updatedTransaction.title = transaction.title
                updatedTransaction.subtitle = transaction.subtitle
                updatedTransaction.amount = amount
                updatedTransaction.date = transaction.date
                updatedTransaction.icon = transaction.icon
                updatedTransaction.colorHex = transaction.color.toHex() ?? "#000000"
                updatedTransaction.note = transaction.notes
                updatedTransaction.type = amount < 0 ? "expense" : "income"
                
                try await transactionRepo.updateTransaction(updatedTransaction)
                
                // Sync Social Data if splits exist
                if let splits = updatedTransaction.splits, !splits.isEmpty {
                    // Derive groupId from existing SplitRequest (if any)
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
        // 1. Check if it's a "Payment Received" transaction linked to a split
        if transaction.type == "income", let requestId = transaction.source, !requestId.isEmpty {
            // It's linked. Check status.
            Task {
                do {
                    let doc = try await Firestore.firestore().collection("split_requests").document(requestId).getDocument()
                    if let request = try? doc.data(as: FirestoreModels.SplitRequest.self) {
                        if request.status == .paid {
                            // BLOCK DELETION
                            await MainActor.run {
                                errorState.show("This transaction verifies a paid split. Please unmark the split as paid if you wish to undo this payment.")
                            }
                            return
                        }
                    }
                    // If not paid, allow delete
                    await MainActor.run {
                        transactionToDelete = transaction
                        showDeleteConfirmation = true
                    }
                } catch {
                    // Fail safe
                    await MainActor.run {
                        errorState.show("Could not verify split status. Please try again.")
                    }
                }
            }
        } else {
            // Normal transaction
            transactionToDelete = transaction
            showDeleteConfirmation = true
        }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.TransactionModel) {
        guard let id = transaction.id else { return }
        
        // Optimistic Removal globally via repository
        // Must be done inside withAnimation to trigger instant layout update
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
                                transactionRepo.undoDelete(id: id) // Restore linked income transactions on error
                            }
                            errorState.show("Failed to delete transaction")
                        }
                    }
                }
            }
        )
    }
    
    private func generateCSV() -> String {
        var csv = "Date,Title,Category,Amount,Type,Note\n"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for transaction in sortedTransactions {
            let date = formatter.string(from: transaction.date)
            // Escape commas and newlines
            let title = "\"" + transaction.title.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let category = "\"" + (transaction.subtitle ?? "Uncategorized").replacingOccurrences(of: "\"", with: "\"\"") + "\""
            let amount = String(format: "%.2f", transaction.amount)
            let type = transaction.type
            let note = "\"" + (transaction.note ?? "").replacingOccurrences(of: "\"", with: "\"\"") + "\""
            
            csv += "\(date),\(title),\(category),\(amount),\(type),\(note)\n"
        }
        return csv
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(AppRadius.medium)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(AppRadius.small)
    }
}
