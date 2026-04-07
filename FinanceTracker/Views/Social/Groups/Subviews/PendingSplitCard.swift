import SwiftUI
import FirebaseFirestore

struct PendingSplitCard: View {
    let split: FirestoreModels.SplitRequest
    let userId: String
    let presentation: RequestPresentation
    let onAction: (RequestAction) -> Void
    
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository
    
    /// Whether the current user is the sender (creditor) of this split request
    private var isSender: Bool { split.fromUid == userId }
    
    private var otherUserId: String {
        isSender ? split.toUid : split.fromUid
    }
    
    private var accentColor: Color {
        if split.isSettlement == true {
            return Color(hex: split.colorHex ?? "#34C759")
        }
        if presentation.badge == "Awaiting Payment" || presentation.badge == "Accepted" {
            return .blue
        }
        return isSender ? Color.functionalSuccess : .orange
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.element) {
            // Icon
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: split.isSettlement == true ? "arrow.left.arrow.right" : (isSender ? "creditcard.fill" : "arrow.up.right"))
                        .font(.headline)
                        .foregroundColor(accentColor)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(presentation.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .layoutPriority(1)
                    
                    if split.isGuest != true, userPremiumRepo.isPremium(userId: otherUserId) == true {
                        PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: otherUserId))
                    }
                }

                if split.isGuest == true || presentation.cardBadge != nil {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            if split.isGuest == true {
                                guestBadge
                            }
                            if let cardBadge = presentation.cardBadge {
                                statusBadge(text: cardBadge)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            if split.isGuest == true {
                                guestBadge
                            }
                            if let cardBadge = presentation.cardBadge {
                                statusBadge(text: cardBadge)
                            }
                        }
                    }
                }
                
                Text(presentation.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                // Time
                Text("\(presentation.timestampPrefix) \(timeAgo(from: split.createdAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // FIX 3.5: Guest explanation
                if split.isGuest == true {
                    Text("Manual tracking — no account")
                        .font(.caption2)
                        .foregroundColor(AppColors.functionalExpense) // warning orange for guest manual tracking
                }
            }
            .layoutPriority(1)
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if let secondaryAction = presentation.secondaryAction {
                    actionButton(secondaryAction)
                }
                if let primaryAction = presentation.primaryAction {
                    actionButton(primaryAction)
                }
            }
        }
        .padding(AppSpacing.element)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(accentColor, lineWidth: 1)
        )
        .onAppear {
            if split.isGuest != true {
                userPremiumRepo.prefetch(userIds: [otherUserId])
            }
        }
    }

    @ViewBuilder
    private func actionButton(_ action: RequestAction) -> some View {
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
                .foregroundColor(action.emphasis == .primary ? .white : .secondary)
                .frame(width: 44, height: 44)
                .background(buttonBackgroundColor(for: action))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(action.title)
    }

    private var guestBadge: some View {
        Text("Guest")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.compact)
            .padding(.vertical, 4)
            .background(Color.secondary)
            .clipShape(Capsule())
    }

    private func statusBadge(text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(accentColor.opacity(0.12))
            .clipShape(Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.9)
    }

    private func buttonBackgroundColor(for action: RequestAction) -> Color {
        switch action.emphasis {
        case .primary:
            return action == .confirmPaymentReceived ? AppColors.functionalIncome : accentColor
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
