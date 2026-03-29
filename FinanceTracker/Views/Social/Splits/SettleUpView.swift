import SwiftUI

struct SettleUpView: View {
    let group: FirestoreModels.Group
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = SocialRepository()
    
    @State private var amount: String = ""
    @State private var selectedPayerId: String = "" // Usually self
    @State private var selectedReceiverId: String = ""
    @State private var paymentMethod: String = "Cash"
    
    // New Fields
    @State private var selectedCategoryId: String? = nil
    @State private var transactionNotes: String = ""
    @EnvironmentObject var budgetRepo: BudgetRepository
    
    let paymentMethods = ["Cash", "Venmo", "PayPal", "Bank Transfer", "Other"]
    
    // Derived: Current User is Payer?
    var isCurrentUserPayer: Bool {
        return selectedPayerId == appState.currentUserId
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Who is paying?")) {
                    Picker("Payer", selection: $selectedPayerId) {
                        Text("You").tag(appState.currentUserId)
                        ForEach(group.members.filter { $0 != appState.currentUserId }, id: \.self) { memberId in
                            Text(getMemberName(id: memberId)).tag(memberId)
                        }
                    }
                }
                
                Section(header: Text("Who is receiving?")) {
                    Picker("Receiver", selection: $selectedReceiverId) {
                        ForEach(group.members.filter { $0 != selectedPayerId }, id: \.self) { memberId in
                            Text(getMemberName(id: memberId)).tag(memberId)
                        }
                    }
                }
                
                Section(header: Text("How much?")) {
                    HStack {
                        Text("$")
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section(header: Text("Method")) {
                    Picker("Payment Method", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                }
                
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategoryId) {
                        ForEach(budgetRepo.budgets.filter { $0.category.lowercased() != "income" }) { budget in
                            Text(budget.category).tag(budget.id as String?)
                        }
                    }
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextField("Notes", text: $transactionNotes)
                }
                
                Button(action: { HapticManager.shared.light(); 
                    settleUp()
                }) {
                    Text("Record Payment")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppSpacing.margin)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Settle Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { HapticManager.shared.light();  dismiss() }
                }
            }
            .onAppear {
                selectedPayerId = appState.currentUserId
                // Default receiver: first non-self member
                if let first = group.members.first(where: { $0 != appState.currentUserId }) {
                    selectedReceiverId = first
                }
                
                // Default Category
                if let settlementCat = budgetRepo.budgets.first(where: { $0.category.lowercased() == "settlement" }) {
                    selectedCategoryId = settlementCat.id
                }
            }
        }
    }
    
    func getMemberName(id: String) -> String {
        // Fallback to ID if not found, ideally fetch from cache
        if id == appState.currentUserId { return "You" }
        if let friend = appState.friendRepo.friends.first(where: { $0.id == id }) { return friend.name }
        if let guest = appState.guestRepo.guests.first(where: { $0.id == id }) { return guest.name }
        if let name = group.memberNames?[id] { return name }
        return "Member"
    }
    
    func settleUp() {
        guard let amountDouble = Double(amount), !selectedReceiverId.isEmpty else { return }

        // SECURITY: Can only record a settlement where the current user is the payer.
        // Client-side writes to another user's transaction subcollection are blocked by Firestore rules.
        guard selectedPayerId == appState.currentUserId else {
            DebugLogger.log("⚠️ SettleUpView: Cannot record settlement on behalf of another user.")
            return
        }

        Task {
            do {
                try await SocialTransactionManager.shared.settleUp(
                    payerId: selectedPayerId,
                    receiverId: selectedReceiverId,
                    groupId: group.id,
                    amount: amountDouble,
                    currency: group.defaultCurrency ?? CurrencyManager.shared.mainCurrency,
                    payerName: getMemberName(id: selectedPayerId),
                    receiverName: getMemberName(id: selectedReceiverId),
                    method: paymentMethod,
                    note: transactionNotes.isEmpty ? nil : transactionNotes
                )
                dismiss()
            } catch {
                DebugLogger.log("Failed to settle up: \(error)")
            }
        }
    }
}
