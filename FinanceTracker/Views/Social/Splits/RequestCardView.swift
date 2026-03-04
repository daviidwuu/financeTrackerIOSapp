import SwiftUI

struct RequestCardView: View {
    let request: FirestoreModels.SplitRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository
    
    var body: some View {
        let iconName = request.isSettlement == true ? "arrow.turn.down.left" : (request.icon ?? "banknote.fill")
        let colorHex = request.isSettlement == true ? "#34C759" : (request.colorHex ?? "#FF9F0A") // Default orange
        
        HStack(spacing: AppSpacing.element) {
            // Avatar / Icon
            Circle()
                .fill(Color(hex: colorHex).opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: iconName)
                        .font(.headline)
                        .foregroundColor(Color(hex: colorHex))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Primary Info: Sender Name
                let senderName: String = {
                    return appState.userResolver.resolveName(for: request.fromUid, fallbackName: request.fromName)
                }()
                
                if request.isSettlement == true {
                    Text("Settlement")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Text(senderName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if userPremiumRepo.isPremium(userId: request.fromUid) == true {
                            PremiumBadge(size: .small)
                        }
                        
                        Text("paid you $\(String(format: "%.2f", abs(request.amount)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    HStack(spacing: 8) {
                        Text(senderName)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if userPremiumRepo.isPremium(userId: request.fromUid) == true {
                            PremiumBadge(size: .small)
                        }
                    }
                    
                    // Secondary Info: Request Details
                    let note = request.note?.isEmpty == false ? request.note! : "Expense"
                    Text("requests $\(String(format: "%.2f", abs(request.amount))) for \(note)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Timestamp
                Text("Requested \(timeAgo(from: request.createdAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
                        .background(Color.secondaryCardBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    HapticManager.shared.success()
                    onAccept()
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.themeAccent)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppSpacing.element)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(Color(hex: colorHex), lineWidth: 1)
        )
        .onAppear {
            userPremiumRepo.prefetch(userIds: [request.fromUid])
        }
        // Removed gray background as requested
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
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
            category: "Food",
            icon: "fork.knife",
            colorHex: "#FFA500",
            status: .pending,
            dependencyId: nil,
            lastNudgedAt: nil,
            originalTotalAmount: 50.0,
            isGuest: false,
            createdAt: Date()
        ),
        onAccept: {},
        onDecline: {}
    )
    .padding()
}
