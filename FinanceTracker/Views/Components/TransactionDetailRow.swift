import SwiftUI

/// Shared detail row component used in TransactionDetailView,
/// SplitRequestDetailView, and GroupTransactionDetailView.
struct TransactionDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    private let valueView: AnyView?
    
    init(icon: String, title: String, value: String, color: Color) {
        self.icon = icon
        self.title = title
        self.value = value
        self.color = color
        self.valueView = nil
    }
    
    init<V: View>(icon: String, title: String, color: Color, @ViewBuilder value: () -> V) {
        self.icon = icon
        self.title = title
        self.value = ""
        self.color = color
        self.valueView = AnyView(value())
    }
    
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
                if let valueView {
                    valueView
                } else {
                    Text(value)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            Spacer()
        }
        .padding(AppSpacing.element)
    }
}
