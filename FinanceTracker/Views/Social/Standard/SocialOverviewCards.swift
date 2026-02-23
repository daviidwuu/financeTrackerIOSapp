import SwiftUI

struct SocialStatCard: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(AppTypography.sectionHeader)
                .foregroundColor(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
    }
}

struct SocialTwoCardRow: View {
    let left: SocialStatCard
    let right: SocialStatCard
    
    var body: some View {
        HStack(spacing: 12) {
            left
            right
        }
    }
}

