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
    let payerName: String? // If provided, show payer avatar instead of category icon
    let payerAvatarColor: String? // Hex color for avatar background
    let originalAmount: Double? // For foreign currency display
    let currencyCode: String? // For foreign currency display
    
    init(title: String, subtitle: String?, amount: Double, date: Date, type: String, category: String?, iconName: String?, colorHex: String?, amountColor: Color, statusBadge: String?, payerName: String? = nil, payerAvatarColor: String? = nil, originalAmount: Double? = nil, currencyCode: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.date = date
        self.type = type
        self.category = category
        self.iconName = iconName
        self.colorHex = colorHex
        self.amountColor = amountColor
        self.statusBadge = statusBadge
        self.payerName = payerName
        self.payerAvatarColor = payerAvatarColor
        self.originalAmount = originalAmount
        self.currencyCode = currencyCode
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            if let payer = payerName, type != "settlement" {
                // Show payer's avatar (initial on colored circle)
                ZStack {
                    Circle()
                        .fill(payerAvatarColor != nil ? Color(hex: payerAvatarColor!) : Color.random(seed: payer))
                        .frame(width: 48, height: 48)
                    Text(String(payer.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            } else {
                CategoryIconView(
                    category: category ?? "Uncategorized",
                    iconOverride: iconName,
                    colorOverride: colorHex,
                    type: type
                )
            }
            
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
                
                if let originalAmount = originalAmount, let currencyCode = currencyCode {
                    Text("\(currencyCode) \(String(format: "%.2f", abs(originalAmount)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
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
        case "pending", "needs response", "awaiting response", "you owe", "settlement request":
            return .orange
        case "accepted", "awaiting payment", "awaiting payments":
            return .blue
        case "paid", "settled", "fully settled", "fully paid":
            return Color.functionalSuccess
        case "declined":
            return Color.functionalError
        default: 
            return .secondary
        }
    }
}
