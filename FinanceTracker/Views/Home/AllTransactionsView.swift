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
    @State private var selectedMonth: Date? = Date()
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
        // Use calendarTransactions when a specific month is selected,
        // otherwise use the main paginated transactions feed
        // (but use allTransactions when searching to avoid missing older results)
        let sourceTransactions: [FirestoreModels.TransactionModel]
        if selectedMonth != nil {
            sourceTransactions = transactionRepo.calendarTransactions
        } else if !searchText.isEmpty {
            // When searching in "All Time", use the full unpaginated history
            sourceTransactions = transactionRepo.allTransactions
        } else {
            sourceTransactions = transactionRepo.transactions
        }
        
        return sourceTransactions.filter { transaction in
            // Day filter (within the selected month)
            let matchesDay: Bool
            if let date = selectedDate {
                matchesDay = Calendar.current.isDate(transaction.date, inSameDayAs: date)
            } else {
                matchesDay = true
            }
            
            // Category filter
            let cName = appState.budgetRepo.getCategory(for: transaction.categoryId ?? "")?.category ?? "Uncategorized"
            let matchesCategory = selectedCategory == nil || 
                                 cName == selectedCategory
            
            // Type filter
            let matchesType = selectedType == "All" ||
                            (selectedType == "Income" && transaction.type == "income") ||
                            (selectedType == "Expense" && transaction.type == "expense")
            
            // Search filter (title, note, or category name)
            let matchesSearch = searchText.isEmpty || 
                               transaction.title.localizedCaseInsensitiveContains(searchText) ||
                               (transaction.note?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                               cName.localizedCaseInsensitiveContains(searchText)
            
            return matchesDay && matchesCategory && matchesType && matchesSearch
        }
    }
    
    var sortedTransactions: [FirestoreModels.TransactionModel] {
        filteredTransactions.sorted { t1, t2 in
            switch sortBy {
            case "Amount":
                return sortAscending ? abs(t1.amount) < abs(t2.amount) : abs(t1.amount) > abs(t2.amount)
            case "Category":
                let c1 = appState.budgetRepo.getCategory(for: t1.categoryId ?? "")?.category ?? "Uncategorized"
                let c2 = appState.budgetRepo.getCategory(for: t2.categoryId ?? "")?.category ?? "Uncategorized"
                return sortAscending ? c1 < c2 : c1 > c2
            default: // Date
                return sortAscending ? t1.date < t2.date : t1.date > t2.date
            }
        }
    }
    
    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedType != "All" || !searchText.isEmpty || selectedDate != nil
    }
    
    /// FIX #7: Separate income and expense stats to avoid meaningless mixed totals.
    var transactionStats: (count: Int, total: Double, average: Double) {
        let count = filteredTransactions.count
        let expenses = filteredTransactions.filter { $0.amount < 0 }
        let incomes = filteredTransactions.filter { $0.amount >= 0 }

        // Show expense stats by default (most useful), fall back to income if no expenses
        let relevantAmounts = expenses.isEmpty ? incomes.map { $0.amount } : expenses.map { abs($0.amount) }
        let total = DecimalPrecision.sum(relevantAmounts)
        let average = relevantAmounts.isEmpty ? 0.0 : DecimalPrecision.divide(total, Double(relevantAmounts.count))
        return (count, total, average)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()

            // Main Content
             List {
                 // Scroll offset tracker + spacer for fixed header
                 ScrollOffsetTracker()
                     .listRowSeparator(.hidden)
                     .listRowBackground(Color.clear)
                     .listRowInsets(EdgeInsets())

                 Color.clear.frame(height: 0)
                     .listRowInsets(EdgeInsets())
                     .listRowSeparator(.hidden)
                     .listRowBackground(Color.clear)
                 
                 // Search & Filters Header
                 VStack(spacing: AppSpacing.element) {
                     // Search Bar
                    HStack(alignment: .center) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
                        TextField("Search transactions...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button(action: { HapticManager.shared.light();  searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(AppSpacing.compact)
                    .background(Color.cardBackground)
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
                                Button("All Categories") { HapticManager.shared.light(); 
                                    selectedCategory = nil
                                }
                                
                                Divider()
                                
                                ForEach(budgetRepo.budgets.sorted(by: { $0.category < $1.category })) { budget in
                                    Button(action: { HapticManager.shared.light(); 
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
                                .background(Color.cardBackground)
                                .cornerRadius(AppRadius.small)
                            }
                            
                            // Month Filter
                            Menu {
                                Button(action: { HapticManager.shared.light(); 
                                    selectedMonth = nil
                                }) {
                                    HStack {
                                        Text("All Time")
                                        if selectedMonth == nil {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }

                                Divider()

                                ForEach(0..<12, id: \.self) { offset in
                                    let date = Calendar.current.date(byAdding: .month, value: -offset, to: Date())!
                                    Button(action: { HapticManager.shared.light(); 
                                        selectedMonth = date
                                    }) {
                                        HStack {
                                            Text(monthYearString(from: date))
                                            if let selected = selectedMonth, Calendar.current.isDate(selected, equalTo: date, toGranularity: .month) {
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
                                    Text(selectedMonth == nil ? "All Time" : monthYearString(from: selectedMonth!))
                                        .font(.subheadline)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(Color.cardBackground)
                                .cornerRadius(AppRadius.small)
                            }
                            
                            // Date Filter (Specific Day)
                            if selectedDate == nil {
                                Menu {
                                    if selectedMonth == nil || Calendar.current.isDate(selectedMonth!, equalTo: Date(), toGranularity: .month) {
                                        Button("Today") { HapticManager.shared.light(); 
                                            selectedDate = Date()
                                        }
                                        Button("Yesterday") { HapticManager.shared.light(); 
                                            selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                                        }
                                        Divider()
                                    }
                                    
                                    // Pick from relevant month
                                    let baseDate = selectedMonth ?? Date()
                                    let calendar = Calendar.current
                                    if let range = calendar.range(of: .day, in: .month, for: baseDate) {
                                        let days = Array(range.reversed())
                                        ForEach(days, id: \.self) { day in
                                            let dayComponents = DateComponents(year: calendar.component(.year, from: baseDate), month: calendar.component(.month, from: baseDate), day: day)
                                            if let date = calendar.date(from: dayComponents),
                                               calendar.startOfDay(for: date) <= calendar.startOfDay(for: Date()) {
                                                Button(action: { HapticManager.shared.light(); 
                                                    selectedDate = calendar.startOfDay(for: date)
                                                }) {
                                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "calendar.day.timeline.left")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                        .frame(width: 36, height: 36)
                                        .background(Color.cardBackground)
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
                                        .background(Color.cardBackground)
                                        .cornerRadius(AppRadius.small)
                                }
                            }
                            
                            // Sort Menu
                            Menu {
                                Button(action: { HapticManager.shared.light();  sortBy = "Date"; sortAscending = false }) {
                                    Label("Newest First", systemImage: sortBy == "Date" && !sortAscending ? "checkmark" : "")
                                }
                                Button(action: { HapticManager.shared.light();  sortBy = "Date"; sortAscending = true }) {
                                    Label("Oldest First", systemImage: sortBy == "Date" && sortAscending ? "checkmark" : "")
                                }
                                Divider()
                                Button(action: { HapticManager.shared.light();  sortBy = "Amount"; sortAscending = false }) {
                                    Label("Highest Amount", systemImage: sortBy == "Amount" && !sortAscending ? "checkmark" : "")
                                }
                                Button(action: { HapticManager.shared.light();  sortBy = "Amount"; sortAscending = true }) {
                                    Label("Lowest Amount", systemImage: sortBy == "Amount" && sortAscending ? "checkmark" : "")
                                }
                                Divider()
                                Button(action: { HapticManager.shared.light();  sortBy = "Category"; sortAscending = true }) {
                                    Label("Category A-Z", systemImage: sortBy == "Category" && sortAscending ? "checkmark" : "")
                                }
                                Button(action: { HapticManager.shared.light();  sortBy = "Category"; sortAscending = false }) {
                                    Label("Category Z-A", systemImage: sortBy == "Category" && !sortAscending ? "checkmark" : "")
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Color.cardBackground)
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
                    ForEach(sortedTransactions, id: \.id) { transaction in
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
                                .tint(Color.functionalError)
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

                    // Load More button (only in "All Time" paginated mode)
                    if selectedMonth == nil && transactionRepo.canLoadMore {
                        Button(action: { HapticManager.shared.light(); 
                            transactionRepo.loadMore()
                        }) {
                            HStack {
                                Spacer()
                                Text("Load More")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.top, -20)
            // Use calendarTransactions for month filtering (does NOT touch main transactions)
            .onChange(of: selectedMonth) { _, newMonth in
                if let month = newMonth {
                    transactionRepo.setCalendarMonth(month)
                }
            }
            .onAppear {
                // Set calendar month for initial fetch if a month is selected
                if let month = selectedMonth {
                    transactionRepo.setCalendarMonth(month)
                }
            }
            
            .errorBanner(errorState)
            .undoableBanner(undoState)
            .sheet(item: $selectedTransaction) { selected in
                let resolved = sortedTransactions.first(where: { $0.id == selected.id }) ?? selected
                TransactionDetailView(transaction: resolved) { original, updated in
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
                Button("Delete", role: .destructive) { HapticManager.shared.light(); 
                    if let tx = transactionToDelete {
                        deleteTransaction(tx)
                    }
                }
                Button("Cancel", role: .cancel) { HapticManager.shared.light();  
                    transactionToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete this transaction? This action cannot be undone.")
            }
        }
        .overlayHeader(.navigation(title: "Transactions", onBack: { dismiss() }))
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
                updatedTransaction.categoryId = transaction.categoryId
                updatedTransaction.amount = amount
                updatedTransaction.date = transaction.date
                updatedTransaction.note = transaction.notes
                updatedTransaction.type = amount < 0 ? "expense" : "income"
                updatedTransaction.latitude = transaction.latitude
                updatedTransaction.longitude = transaction.longitude
                updatedTransaction.locationName = transaction.locationName
                
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
        if transaction.type == "income", let requestId = transaction.source, !requestId.isEmpty, requestId != "recurring", !requestId.hasPrefix("recurring_") {
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
            let cName = appState.budgetRepo.getCategory(for: transaction.categoryId ?? "")?.category ?? "Uncategorized"
            let category = "\"" + cName.replacingOccurrences(of: "\"", with: "\"\"") + "\""
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
        .background(Color.cardBackground)
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
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.small)
    }
}
