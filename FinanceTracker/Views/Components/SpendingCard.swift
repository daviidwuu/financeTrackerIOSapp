import SwiftUI

struct SpendingCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold)) // Larger and cleaner
                        .foregroundColor(color)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                Text(CurrencyFormatter.format(amount))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
        }
        .padding(AppSpacing.element)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium) // Use AppRadius
    }
}
