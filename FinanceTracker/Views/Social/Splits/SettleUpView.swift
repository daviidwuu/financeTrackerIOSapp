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
                
                Button(action: {
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
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                selectedPayerId = appState.currentUserId
                // Default receiver: first non-self member
                if let first = group.members.first(where: { $0 != appState.currentUserId }) {
                    selectedReceiverId = first
                }
            }
        }
    }
    
    func getMemberName(id: String) -> String {
        // Fallback to ID if not found, ideally fetch from cache
        if id == appState.currentUserId { return "You" }
        return appState.friendRepo.friends.first(where: { $0.id == id })?.name ?? "Member"
    }
    
    func settleUp() {
        guard let amountDouble = CurrencyInput.parse(amount), !selectedReceiverId.isEmpty else { return }
        
        Task {
            do {
                try await repo.settleUp(
                    payerId: selectedPayerId,
                    receiverId: selectedReceiverId,
                    groupId: group.id,
                    amount: amountDouble,
                    method: paymentMethod
                )
                dismiss()
            } catch {
                print("Failed to settle up: \(error)")
            }
        }
    }
}
