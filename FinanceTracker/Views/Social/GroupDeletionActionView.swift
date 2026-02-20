import SwiftUI

struct GroupDeletionActionView: View {
    let group: FirestoreModels.Group
    @EnvironmentObject var groupRepo: GroupRepository
    @Environment(\.dismiss) var dismiss
    
    var onActionSubmitted: (() -> Void)? = nil
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: group.color).opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Text(group.icon)
                        .font(.system(size: 40))
                }
                .padding(.top, 40)
                
                VStack(spacing: 8) {
                    Text("Group Deleted")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(group.name) has been deleted by the creator.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("What would you like to do with your transaction history?")
                        .font(.headline)
                        .padding(.top)
                    
                    // Option 1: Keep
                    Button {
                        submitAction(action: "keep")
                    } label: {
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: "doc.text.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Keep Transaction History")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Convert group transactions to personal expenses. Unpaid debts will remain as pending requests between friends.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(AppRadius.small)
                    }
                    
                    // Option 2: Delete
                    Button {
                        submitAction(action: "delete")
                    } label: {
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Delete All History")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Text("Permanently delete all transactions and requests associated with this group.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(AppRadius.small)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                if isProcessing {
                    ProgressView()
                        .padding()
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    private func submitAction(action: String) {
        isProcessing = true
        Task {
            do {
                try await groupRepo.submitDeletionAction(group: group, action: action)
                await MainActor.run {
                    isProcessing = false
                    dismiss()
                    onActionSubmitted?()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
