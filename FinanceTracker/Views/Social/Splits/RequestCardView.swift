import SwiftUI

struct RequestCardView: View {
    let request: FirestoreModels.SplitRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar / Icon
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "banknote.fill")
                        .font(.headline)
                        .foregroundColor(.orange)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                // Primary Info: Sender Name
                let senderName: String = {
                    if let name = request.fromName, !name.isEmpty {
                        return name
                    }
                    if let friend = appState.friendRepo.friends.first(where: { $0.id == request.fromUid }) {
                        return friend.name
                    }
                    return "Friend"
                }()
                
                Text(senderName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                // Secondary Info: Request Details
                let note = request.note?.isEmpty == false ? request.note! : "Expense"
                Text("requests $\(String(format: "%.2f", abs(request.amount))) for \(note)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button(action: {
                    HapticManager.shared.light()
                    onDecline()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    HapticManager.shared.success()
                    onAccept()
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.backgroundPrimary)
                        .frame(width: 32, height: 32)
                        .background(Color.functionalSuccess)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppSpacing.element)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
        // No red border, consistent with FriendRequestCard
    }
}

#Preview {
    RequestCardView(
        request: FirestoreModels.SplitRequest(
            id: "1",
            transactionId: "tx1",
            groupId: nil,
            fromUid: "user1",
            toUid: "user2",
            fromName: "Alice",
            toName: "Bob",
            amount: 25.0,
            currency: "USD",
            note: "Dinner",
            status: .pending,
            dependencyId: nil,
            lastNudgedAt: nil,
            createdAt: Date()
        ),
        onAccept: {},
        onDecline: {}
    )
    .padding()
}
