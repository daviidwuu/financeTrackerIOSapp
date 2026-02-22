import SwiftUI

struct SocialTransactionCardView: View {
    let title: String
    let subtitle: String?
    let amount: Double
    let date: Date
    let type: String // "expense", "income", "settlement"
    let category: String?
    let iconName: String?
    let colorHex: String?
    let amountColor: Color // Determines if amount is red, green, or primary
    let statusBadge: String? // "pending", "paid", etc.
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            CategoryIconView(
                category: category ?? "Uncategorized",
                iconOverride: iconName,
                colorOverride: colorHex,
                type: type
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Status Badge
                if let status = statusBadge, !status.isEmpty {
                    Text(status.capitalized)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor(status).opacity(0.1))
                        .foregroundColor(statusColor(status))
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", abs(amount)))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(amountColor)
                
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .padding(AppSpacing.element)
        .contentShape(Rectangle()) // Make tappable
    }
    
    func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "pending", "awaiting payments", "you owe": 
            return .orange
        case "paid", "settled", "accepted", "fully settled": 
            return .green
        case "declined": 
            return .red
        default: 
            return .secondary
        }
    }
}
