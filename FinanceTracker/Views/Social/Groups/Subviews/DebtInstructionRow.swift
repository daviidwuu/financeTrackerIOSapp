import SwiftUI
import FirebaseFirestore

struct DebtInstructionRow: View {
    let debtorName: String
    let creditorName: String
    let amount: Double
    var currency: String = ""
    
    var body: some View {
        HStack(spacing: AppSpacing.compact) {
            HStack(spacing: AppSpacing.compact) {
                ProfileAvatar(text: String(debtorName.prefix(1)), color: .secondary, size: AppSize.avatarSmall)
                Text(debtorName).font(.subheadline).fontWeight(.medium).lineLimit(1)
            }
            Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
            HStack(spacing: AppSpacing.compact) {
                ProfileAvatar(text: String(creditorName.prefix(1)), color: .secondary, size: AppSize.avatarSmall)
                Text(creditorName).font(.subheadline).fontWeight(.medium).lineLimit(1)
            }
            Spacer()
            Text("\(currency.isEmpty ? "$" : currency) \(String(format: "%.2f", amount))").font(.subheadline).fontWeight(.bold)
        }
        .padding(AppSpacing.compact)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.small)
    }
}
