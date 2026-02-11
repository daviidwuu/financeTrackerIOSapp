import SwiftUI

struct RequestCardView: View {
    let request: FirestoreModels.SplitRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // "Red Card" Icon
            Circle()
                .fill(Color.red.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.red)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Split Request")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                let senderName: String = {
                    if let name = request.fromName, !name.isEmpty {
                        return name
                    }
                    // Fallback to friend lookup
                    if let friend = AppState.shared.friendRepo.friends.first(where: { $0.id == request.fromUid }) {
                        return friend.name
                    }
                    return "Friend"
                }()
                
                Text("\(senderName) requests $\(String(format: "%.2f", abs(request.amount)))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let note = request.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.light()
                    onDecline()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    HapticManager.shared.success()
                    onAccept()
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        // Red border to emphasize importance
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    RequestCardView(
        request: FirestoreModels.SplitRequest(
            id: "1",
            transactionId: "tx1",
            fromUid: "user1",
            toUid: "user2",
            fromName: "Alice",
            amount: 25.0,
            note: "Dinner",
            status: .pending,
            createdAt: Date()
        ),
        onAccept: {},
        onDecline: {}
    )
    .padding()
}
