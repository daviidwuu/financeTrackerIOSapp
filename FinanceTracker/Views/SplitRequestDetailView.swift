import SwiftUI

struct SplitRequestDetailView: View {
    let request: FirestoreModels.SplitRequest
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    // Repositories
    @StateObject private var socialRepo = SocialRepository()
    
    // State
    @State private var relatedSplits: [FirestoreModels.SplitRequest] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Hero Section (Amount)
                    VStack(spacing: 8) {
                        Text(request.note ?? "Split Expense")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(request.dateString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "$%.2f", request.amount))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        // Status Badge
                        StatusBadge(status: request.status)
                            .padding(.top, 8)
                    }
                    .padding(.top, 40)
                    
                    // 2. Info Card
                    VStack(spacing: 16) {
                        InfoRow(icon: "person.fill", title: "Payer", value: request.fromName ?? "Unknown")
                        Divider()
                        InfoRow(icon: "arrow.right", title: "Recipient", value: request.toName ?? "Unknown")
                        if let groupName = request.groupName {
                            Divider()
                            InfoRow(icon: "person.3.fill", title: "Group", value: groupName)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, AppSpacing.margin)
                    
                    // 3. Actions
                    if request.toUid == appState.currentUserId && request.status == .pending {
                        Button(action: markAsPaid) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark as Paid")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.top, 16)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
    }
    
    private func markAsPaid() {
        HapticManager.shared.medium()
        Task {
            do {
                try await socialRepo.markSplitAsPaid(
                    request: request,
                    currentUserId: appState.currentUserId,
                    currentUserName: appState.userName
                )
                dismiss() // Return to group view
            } catch {
                print("Error marking as paid: \(error)")
                HapticManager.shared.error()
            }
        }
    }
}

// MARK: - Subviews

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

struct StatusBadge: View {
    let status: FirestoreModels.SplitRequest.RequestStatus
    
    var color: Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .blue
        case .declined: return .red
        case .paid: return .green
        case .blocked_by_group: return .gray
        case .blocked_by_friendship: return .gray
        }
    }
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// Helper extension for date display
extension FirestoreModels.SplitRequest {
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var groupName: String? {
        // This is a bit of a hack since SplitRequest doesn't store groupName directly usually,
        // but we might want to fetch it or pass it in. 
        // For now, return nil or rely on parent view passing it if we change init.
        // Assuming we might add it to the model later or look it up.
        return nil 
    }
    
    var toName: String? {
        // Should query user or friend repo, but for now specific ID check or passed name
        return nil // Placeholder
    }
}
