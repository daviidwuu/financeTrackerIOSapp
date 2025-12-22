import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: AppSpacing.element) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.3))
                .padding(.bottom, AppSpacing.compact)
            
            VStack(spacing: AppSpacing.compact) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.section)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: {
                    HapticManager.shared.light()
                    action()
                }) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, AppSpacing.element)
                        .padding(.vertical, AppSpacing.compact)
                        .background(Color.primary)
                        .foregroundColor(Color.backgroundPrimary)
                        .cornerRadius(AppRadius.button)
                }
                .padding(.top, AppSpacing.compact)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.section)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        EmptyStateView(
            icon: "tray.fill",
            title: "No Transactions",
            message: "Your financial journey starts here. Add your first transaction to see it show up!",
            actionTitle: "Add Transaction",
            action: {}
        )
    }
}
