import SwiftUI
import FirebaseFirestore

struct TransactionDetailView: View {
    @State private var transaction: FirestoreModels.Transaction
    @State private var showEditSheet = false
    @Environment(\.dismiss) var dismiss
    
    // Callback for saving changes
    var onSave: ((FirestoreModels.Transaction, Transaction) -> Void)?
    
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
}

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
