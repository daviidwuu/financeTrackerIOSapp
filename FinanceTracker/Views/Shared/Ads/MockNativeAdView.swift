import SwiftUI

struct MockNativeAdView: View {
    @Environment(\.colorScheme) var colorScheme
    var hasBackground: Bool = true
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "sparkles")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Ad")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                    
                    Text("FinanceTracker Premium")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text("Unlock exclusive features and analytics today.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.tertiaryLabel)
                .font(.caption)
        }
        .padding(AppSpacing.element)
        .background(hasBackground ? Color(uiColor: .secondarySystemBackground) : Color.clear)
        .cornerRadius(hasBackground ? AppRadius.medium : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            // Placeholder: Do nothing for now
        }
    }
}

#Preview {
    VStack {
        MockNativeAdView()
            .padding()
        MockNativeAdView(hasBackground: false)
            .padding()
            .background(Color.blue.opacity(0.1))
    }
}
