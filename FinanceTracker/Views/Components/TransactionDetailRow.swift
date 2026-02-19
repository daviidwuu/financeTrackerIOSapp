import SwiftUI

/// Shared detail row component used in TransactionDetailView,
/// SplitRequestDetailView, and GroupTransactionDetailView.
struct TransactionDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                .fill(color.opacity(0.1))
                .frame(width: 32, height: 32)
                Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(AppSpacing.element)
    }
}
