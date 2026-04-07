import SwiftUI

struct RequestCardView: View {
    let request: FirestoreModels.SplitRequest
    var showsActions: Bool = true
    let onAction: (RequestAction) -> Void
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository
    
    var body: some View {
        let iconName = request.isSettlement == true ? "arrow.turn.down.left" : (request.icon ?? "banknote.fill")
        let colorHex = request.isSettlement == true ? "#34C759" : (request.colorHex ?? "#FF9F0A") // Default orange
        let currentUserId = appState.currentUserId
        let otherUserId = request.fromUid == currentUserId ? request.toUid : request.fromUid
        let counterpartyName = appState.userResolver.resolveName(
            for: otherUserId,
            fallbackName: request.fromUid == currentUserId ? request.toName : request.fromName
        )
        let presentation = request.presentation(for: currentUserId, counterpartyName: counterpartyName)
        
        HStack(alignment: .center, spacing: AppSpacing.element) {
            // Avatar / Icon
            Circle()
                .fill(Color(hex: colorHex).opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: iconName)
                        .font(.headline)
                        .foregroundColor(Color(hex: colorHex))
                )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(presentation.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .layoutPriority(1)
                    
                    if request.isGuest != true, userPremiumRepo.isPremium(userId: otherUserId) == true {
                        PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: otherUserId))
                    }
                }

                if let cardBadge = presentation.cardBadge {
                    statusBadge(text: cardBadge, accentHex: colorHex)
                }

                Text(presentation.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Timestamp
                Text("\(presentation.timestampPrefix) \(timeAgo(from: request.createdAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .layoutPriority(1)
            
            Spacer()
            
            if showsActions {
                HStack(spacing: 8) {
                    if let secondaryAction = presentation.secondaryAction {
                        actionButton(secondaryAction, accentHex: colorHex)
                    }

                    if let primaryAction = presentation.primaryAction {
                        actionButton(primaryAction, accentHex: colorHex)
                    }
                }
            }
        }
        .padding(AppSpacing.element)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(Color(hex: colorHex), lineWidth: 1)
        )
        .onAppear {
            if request.isGuest != true {
                userPremiumRepo.prefetch(userIds: [otherUserId])
            }
        }
        // Removed gray background as requested
    }

    @ViewBuilder
    private func actionButton(_ action: RequestAction, accentHex: String) -> some View {
        Button(action: {
            switch action.emphasis {
            case .primary:
                HapticManager.shared.success()
            case .secondary:
                HapticManager.shared.light()
            case .destructive:
                HapticManager.shared.warning()
            }
            onAction(action)
        }) {
            Image(systemName: action.compactIconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(foregroundColor(for: action))
                .frame(width: 44, height: 44)
                .background(backgroundColor(for: action, accentHex: accentHex))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(action.title)
    }

    private func statusBadge(text: String, accentHex: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(Color(hex: accentHex))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: accentHex).opacity(0.1))
            .clipShape(Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func foregroundColor(for action: RequestAction) -> Color {
        switch action.emphasis {
        case .primary:
            return .white
        case .secondary, .destructive:
            return .secondary
        }
    }

    private func backgroundColor(for action: RequestAction, accentHex: String) -> Color {
        switch action.emphasis {
        case .primary:
            return action == .confirmPaymentReceived ? AppColors.functionalIncome : Color(hex: accentHex)
        case .secondary, .destructive:
            return Color.secondaryCardBackground
        }
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
        showsActions: true,
        onAction: { _ in }
    )
    .padding()
}
