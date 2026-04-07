import SwiftUI

struct IntroStep: View {
    @Environment(\.colorScheme) var colorScheme
    var requestPermissions: Bool = true
    
    @ViewBuilder
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppColors.brandPrimary.opacity(0.08))
                    .frame(width: 160, height: 160)
                
                Circle()
                    .fill(AppColors.brandPrimary.opacity(0.04))
                    .frame(width: 200, height: 200)
                
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.brandPrimary, AppColors.brandPrimary.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 12) {
                Text("Welcome to wym")
                    .font(AppTypography.heroRounded(size: 28))
                    .multilineTextAlignment(.center)
                
                Text("Let's set up your profile and financial goals in just a few steps.")
                    .font(AppTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.section)
            }
            
            // Login Bypass Link - Only on first page
            NavigationLink(destination: LoginView()) {
                Text("Already have an account? Log In")
                    .font(AppTypography.caption)
                    .foregroundColor(.primary)
                    .padding(.top, 8)
            }
            
            Spacer()
        }
        .onAppear {
            guard requestPermissions else { return }
            LocationManager.shared.requestPermission()
            NotificationManager.shared.requestPermission { _ in }
        }
    }
}
