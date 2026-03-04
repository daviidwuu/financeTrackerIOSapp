import SwiftUI

struct MockAdaptiveBannerView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "star.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
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
                    
                    Text("Try FinanceTracker Pro")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Text("Manage groups with unlimited members.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("Upgrade")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .clipShape(Capsule())
        }
        .padding(AppSpacing.element)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(.ultraThinMaterial)
        )
        // Add a subtle border to the ultraThinMaterial
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { HapticManager.shared.light(); 
            // Placeholder: Do nothing for now
        }
    }
}

#Preview {
    ZStack {
        // Background content to show off ultraThinMaterial
        Color.red.opacity(0.2).edgesIgnoringSafeArea(.all)
        
        VStack {
            Spacer()
            MockAdaptiveBannerView()
                .padding()
        }
    }
}
