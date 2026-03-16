import SwiftUI

struct UndoToast: View {
    let text: String
    let onUndo: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundColor(.green)
            
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()

            Button(action: {
                HapticManager.shared.light()
                onUndo()
            }) {
                Text("Undo")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 24)
    }
}

struct BalanceCard: View {
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository
    
    var userId: String? = nil
    let name: String
    let amount: Double
    let isOwed: Bool 
    let isSelf: Bool
    var currency: String = "" // FIX 1.3: Optional currency label
    
    private var currencySymbol: String {
        currency.isEmpty ? "$" : currency
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatar(text: String(name.prefix(1)), color: Color.random(seed: name), size: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let userId, userPremiumRepo.isPremium(userId: userId) == true {
                        PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: userId))
                    }
                }
                
                Text(isOwed ? "gets \(currencySymbol) \(String(format: "%.0f", amount))" : "owes \(currencySymbol) \(String(format: "%.0f", amount))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isOwed ? .functionalSuccess : .functionalError)
            }
        }
        .padding(AppSpacing.element)
        .background(isSelf ? Color(UIColor.systemBackground) : Color.cardBackground)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isSelf ? Color.primary.opacity(0.1) : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onAppear {
            if let userId {
                userPremiumRepo.prefetch(userIds: [userId])
            }
        }
    }
}
