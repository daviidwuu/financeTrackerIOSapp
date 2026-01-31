import SwiftUI

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
    
    @State private var selectedTransaction: FirestoreModels.Transaction?
    @State private var transactionToEdit: FirestoreModels.Transaction?
    
    init(transactionRepo: TransactionRepository, budgetRepo: BudgetRepository, initialDate: Date? = nil) {
        self.transactionRepo = transactionRepo
        self.budgetRepo = budgetRepo
        _selectedDate = State(initialValue: initialDate)
    }
    
    var filteredTransactions: [FirestoreModels.Transaction] {
        transactionRepo.transactions.filter { transaction in
            // Month filter
            // Month filter (only if no specific date is selected)
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
    
    var sortedTransactions: [FirestoreModels.Transaction] {
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
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search Bar
                    HStack {
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
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Type Filter Segmented Control
                    Picker("Type", selection: $selectedType) {
                        Text("All").tag("All")
                        Text("Income").tag("Income")
                        Text("Expense").tag("Expense")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
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
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
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
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(10)
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
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(10)
                                }
                            }
                            
                            // Export Button
                            if !filteredTransactions.isEmpty {
                                ShareLink(item: generateCSV(), preview: SharePreview("Transactions Export", image: Image(systemName: "doc.text"))) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                        .frame(width: 36, height: 36)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .cornerRadius(10)
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
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
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
                            .padding(.horizontal)
                        }
                    }
                    
                    // Summary Stats
                    HStack(spacing: 16) {
                        StatCard(title: "Total", value: "$\(Int(abs(transactionStats.total)))", icon: "dollarsign.circle")
                        StatCard(title: "Count", value: "\(transactionStats.count)", icon: "number.circle")
                        StatCard(title: "Avg", value: "$\(Int(abs(transactionStats.average)))", icon: "chart.bar")
                    }
                    .padding(.horizontal)
                    
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(sortedTransactions) { transaction in
                                TransactionRow(transaction: transaction)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(16)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .padding(.bottom, 8)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            HapticManager.shared.heavy()
                                            deleteTransaction(transaction)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedTransaction) { transaction in
                TransactionDetailView(transaction: transaction) { original, updated in
                    updateTransaction(original, with: updated)
                }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $transactionToEdit) { transaction in
                AddTransactionView(transactionToEdit: transaction, onSave: { updatedTransaction in
                    updateTransaction(transaction, with: updatedTransaction)
                })
            }
        }
    }
    
    func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
    
    private func updateTransaction(_ entity: FirestoreModels.Transaction, with transaction: Transaction) {
        Task {
            do {
                let amount = Double(transaction.amount) ?? 0.0
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
            } catch {
                print("Failed to update transaction: \(error)")
            }
        }
    }
    
    private func deleteTransaction(_ transaction: FirestoreModels.Transaction) {
        guard let id = transaction.id else { return }
        Task {
            do {
                try await transactionRepo.deleteTransaction(id: id)
            } catch {
                print("Failed to delete transaction: \(error)")
            }
        }
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
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.2))
        .cornerRadius(16)
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
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
