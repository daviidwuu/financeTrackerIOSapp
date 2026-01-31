import SwiftUI
import FirebaseFirestore

struct TransactionDetailView: View {
    @State private var transaction: FirestoreModels.Transaction
    @State private var showEditSheet = false
    @State private var showSplitSheet = false
    @Environment(\.dismiss) var dismiss
    
    // Callback for saving changes
    var onSave: ((FirestoreModels.Transaction, Transaction) -> Void)?
    
    // Repository for creating/deleting income transactions
    @StateObject private var transactionRepo = TransactionRepository()
    
    init(transaction: FirestoreModels.Transaction, onSave: ((FirestoreModels.Transaction, Transaction) -> Void)? = nil) {
        _transaction = State(initialValue: transaction)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Amount Section
                    VStack(spacing: 8) {
                        Text(String(format: "%@$%.2f", transaction.amount > 0 ? "+" : "", abs(transaction.amount)))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(transaction.amount > 0 ? .green : .primary)
                        
                        Text(transaction.type.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: transaction.colorHex).opacity(0.1))
                            .foregroundColor(Color(hex: transaction.colorHex))
                            .cornerRadius(12)
                    }
                    .padding(.top, 20)
                    
                    // Split Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Split with Friends")
                                .font(.headline)
                            Spacer()
                            Button(action: { showSplitSheet = true }) {
                                Image(systemName: "plus.circle.fill") // Using standard SF Symbol
                                    .font(.title2)
                            }
                        }
                        .padding(.horizontal)
                        
                        if let splits = transaction.splits, !splits.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(splits) { split in
                                    HStack {
                                        Text(split.name)
                                            .font(.body)
                                        Spacer()
                                        
                                        Text(String(format: "$%.2f", split.amount))
                                            .foregroundColor(.secondary)
                                        
                                        Button(action: {
                                            toggleSplitPayment(split)
                                        }) {
                                            Image(systemName: split.isPaid ? "checkmark.circle.fill" : "circle")
                                                .foregroundColor(split.isPaid ? .green : .gray)
                                                .font(.title2)
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    
                                    if split.id != splits.last?.id {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                            
                            // Summary
                             HStack {
                                 VStack(alignment: .leading) {
                                     Text("Total Bill")
                                         .font(.caption)
                                         .foregroundColor(.secondary)
                                     Text(String(format: "$%.2f", abs(transaction.amount)))
                                         .font(.headline)
                                 }
                                 Spacer()
                                 VStack(alignment: .trailing) {
                                     Text("Your Net Cost")
                                         .font(.caption)
                                         .foregroundColor(.secondary)
                                     let reimbursed = splits.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
                                     Text(String(format: "$%.2f", abs(transaction.amount) - reimbursed))
                                         .font(.headline)
                                 }
                             }
                             .padding(.horizontal)
                        } else {
                             Button(action: { showSplitSheet = true }) {
                                 HStack {
                                     Image(systemName: "person.2.fill")
                                     Text("Split this bill")
                                 }
                                 .frame(maxWidth: .infinity)
                                 .padding()
                                 .background(Color(UIColor.secondarySystemBackground))
                                 .cornerRadius(12)
                             }
                             .padding(.horizontal)
                        }
                    }
                    
                    // Details Section
                    VStack(spacing: 0) {
                        TransactionDetailRow(icon: "tag.fill", title: "Category", value: transaction.subtitle ?? "Uncategorized")
                        Divider().padding(.leading, 56)
                        
                        if let originalAmount = transaction.originalAmount,
                           let currencyCode = transaction.currencyCode {
                             TransactionDetailRow(icon: "banknote", title: "Original Amount", value: String(format: "%.2f %@", originalAmount, currencyCode))
                             Divider().padding(.leading, 56)
                             
                             if let rate = transaction.exchangeRate {
                                 TransactionDetailRow(icon: "arrow.triangle.2.circlepath", title: "Rate", value: "1 \(CurrencyManager.shared.mainCurrency) ≈ \(String(format: "%.2f", rate)) \(currencyCode)")
                                 Divider().padding(.leading, 56)
                             }
                        }
                        
                        if let note = transaction.note, !note.isEmpty {
                            TransactionDetailRow(icon: "text.alignleft", title: "Note", value: note)
                            Divider().padding(.leading, 56)
                        }
                        
                        TransactionDetailRow(icon: "calendar", title: "Date", value: formattedDate(transaction.date))
                        Divider().padding(.leading, 56)
                        
                        TransactionDetailRow(icon: "clock.fill", title: "Time", value: formattedTime(transaction.date))
                    }
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle(transaction.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showEditSheet = true
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                AddTransactionView(transactionToEdit: transaction, onSave: { updatedTransaction in
                    // Update UI immediately (optimistic)
                    let amount = Double(updatedTransaction.amount) ?? 0.0
                    
                    var newModel = transaction
                    newModel.title = updatedTransaction.title
                    newModel.subtitle = updatedTransaction.subtitle
                    newModel.amount = amount
                    newModel.date = updatedTransaction.date
                    newModel.icon = updatedTransaction.icon
                    newModel.colorHex = updatedTransaction.color.toHex() ?? "#000000"
                    newModel.note = updatedTransaction.notes
                    newModel.type = amount < 0 ? "expense" : "income"
                    
                    self.transaction = newModel
                    
                    // Call parent callback to persist changes
                    onSave?(transaction, updatedTransaction)
                })
                .presentationDetents([.fraction(0.65)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSplitSheet) {
                SplitConfigurationView(transactionAmount: abs(transaction.amount), existingSplits: transaction.splits ?? []) { newSplits in
                    updateSplits(newSplits)
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                transactionRepo.startListening(userId: transaction.userId)
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Logic
    
    private func updateSplits(_ newSplits: [FirestoreModels.Split]) {
        var updatedTransaction = transaction
        updatedTransaction.splits = newSplits
        self.transaction = updatedTransaction
        
        // Persist to Firestore
        Task {
            try? await transactionRepo.updateTransaction(updatedTransaction)
        }
    }
    
    private func toggleSplitPayment(_ split: FirestoreModels.Split) {
        guard var splits = transaction.splits,
              let index = splits.firstIndex(where: { $0.id == split.id }) else { return }
        
        var updatedSplit = split
        updatedSplit.isPaid.toggle()
        
        Task {
            if updatedSplit.isPaid {
                // MARK: Case 1: Paid -> Create Income Transaction
                updatedSplit.paidDate = Date()
                
                // Create a reference first to get the ID
                let db = Firestore.firestore()
                let ref = db.collection("users").document(transaction.userId).collection("transactions").document()
                
                let incomeTransaction = FirestoreModels.Transaction(
                    id: ref.documentID,
                    title: "Split: \(split.name)",
                    subtitle: "Income", // Set Category to "Income" so it's not Unknown
                    amount: split.amount,
                    date: Date(),
                    icon: "dollarsign.circle.fill",
                    colorHex: "#34C759", // Green
                    note: "Reimbursement for \(transaction.title)",
                    type: "income",
                    source: "splitwise",
                    userId: transaction.userId,
                    createdAt: Date()
                )
                
                // Only save ONCE using the reference
                try? ref.setData(from: incomeTransaction)
                
                updatedSplit.incomeTransactionId = ref.documentID
                
            } else {
                // MARK: Case 2: Unpaid -> Delete Income Transaction
                if let incomeId = split.incomeTransactionId {
                    try? await transactionRepo.deleteTransaction(id: incomeId)
                }
                updatedSplit.incomeTransactionId = nil
                updatedSplit.paidDate = nil
            }
            
            // Update Local State
            splits[index] = updatedSplit
            var updatedTransaction = transaction
            updatedTransaction.splits = splits
            
            await MainActor.run {
                self.transaction = updatedTransaction
            }
            
            // Persist Update to Original Transaction
            try? await transactionRepo.updateTransaction(updatedTransaction)
        }
    }
}

// MARK: - Subviews

struct TransactionDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)

                .font(.system(size: 20))
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(16)
    }
}

// MARK: - Split Configuration View
struct SplitConfigurationView: View {
    let transactionAmount: Double
    @State var splits: [FirestoreModels.Split]
    var onSave: ([FirestoreModels.Split]) -> Void
    @Environment(\.dismiss) var dismiss
    
    // Temporary Selection State
    @State private var selectedFriends: Set<String> = []
    
    // State to track manually edited (locked) splits
    @State private var lockedSplitIds: Set<String> = []
    
    // Mock Friends (Top 5)
    let availableFriends = ["Alice", "Bob", "Charlie", "David", "Eve"]
    
    init(transactionAmount: Double, existingSplits: [FirestoreModels.Split], onSave: @escaping ([FirestoreModels.Split]) -> Void) {
        self.transactionAmount = transactionAmount
        self._splits = State(initialValue: existingSplits)
        self.onSave = onSave
        
        // Pre-select existing friends
        let existingNames = Set(existingSplits.map { $0.name })
        self._selectedFriends = State(initialValue: existingNames)
        
        // Assume existing splits from DB are effectively "locked" or intentional, 
        // but for a new edit session we can start fresh or lock them?
        // Let's start with empty locks so user can re-adjust freely, 
        // unless they touch specific fields.
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Select Friends")) {
                    ForEach(availableFriends, id: \.self) { friend in
                        HStack {
                            Text(friend)
                            Spacer()
                            if selectedFriends.contains(friend) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleFriendSelection(friend)
                        }
                    }
                }
                
                if !splits.isEmpty {
                    Section(header: Text("Distribution")) {
                        ForEach(splits) { split in
                            HStack {
                                Text(split.name)
                                Spacer()
                                Text("$").foregroundColor(.secondary)
                                TextField("Amount", value: Binding(
                                    get: {
                                        if let index = splits.firstIndex(where: { $0.id == split.id }) {
                                            return splits[index].amount
                                        }
                                        return 0.0
                                    },
                                    set: { newValue in
                                        adjustSplits(manuallyChangedSplitId: split.id, newValue: newValue)
                                    }
                                ), format: .number.precision(.fractionLength(2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            }
                        }
                    }
                    
                    Section {
                         HStack {
                             Text("Total Distributed")
                             Spacer()
                             let total = splits.reduce(0) { $0 + $1.amount }
                             Text(String(format: "$%.2f / $%.2f", total, transactionAmount))
                                 .foregroundColor(abs(total - transactionAmount) < 0.01 ? .green : .red)
                         }
                         
                         // Yourself
                         HStack {
                             Text("Your Share")
                             Spacer()
                             let total = splits.reduce(0) { $0 + $1.amount }
                             Text(String(format: "$%.2f", max(0, transactionAmount - total)))
                                 .fontWeight(.bold)
                         }
                    }
                }
            }
            .navigationTitle("Split Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(splits)
                        dismiss()
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    private func toggleFriendSelection(_ name: String) {
        if selectedFriends.contains(name) {
            selectedFriends.remove(name)
            splits.removeAll(where: { $0.name == name })
            // If removed friend was locked, remove from lock set
            // Note: We can iterate to find ID if needed, but splits is already updated.
            // Since we can't easily map name -> ID after removal, 
            // we'll just let the ID sit in the Set (it's harmless string).
        } else {
            selectedFriends.insert(name)
            // Add new split - default to 0 temporarily, will be distributed
            let newSplit = FirestoreModels.Split(
                name: name,
                amount: 0.0, 
                isPaid: false
            )
            splits.append(newSplit)
        }
        
        distributeRemainder()
    }
    
    private func adjustSplits(manuallyChangedSplitId: String, newValue: Double) {
        // 1. Lock this split
        lockedSplitIds.insert(manuallyChangedSplitId)
        
        // 2. Update the value
        if let index = splits.firstIndex(where: { $0.id == manuallyChangedSplitId }) {
            splits[index].amount = newValue
        }
        
        // 3. Redistribute remainder among unlocked
        distributeRemainder()
    }
    
    private func distributeRemainder() {
        // Calculate Total Locked Amount
        let lockedTotal = splits
            .filter { lockedSplitIds.contains($0.id) }
            .reduce(0) { $0 + $1.amount }
        
        let remainder = transactionAmount - lockedTotal
        
        // Identify Unlocked Splits
        var unlockedIndices: [Int] = []
        for (index, split) in splits.enumerated() {
            if !lockedSplitIds.contains(split.id) {
                unlockedIndices.append(index)
            }
        }
        
        // Calculate Share
        // Divisor = Unlocked Friends + Yourself (1)
        let divisor = Double(unlockedIndices.count + 1)
        
        let newShare: Double
        if remainder <= 0 {
             newShare = 0 // Locked exceeds total
        } else {
             newShare = remainder / divisor
        }
        
        // Update Unlocked Splits
        for index in unlockedIndices {
            splits[index].amount = newShare
        }
    }
}
