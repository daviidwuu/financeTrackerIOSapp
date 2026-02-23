import SwiftUI

struct IntroStep: View {
    @ViewBuilder
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            // Using a standard color directly to avoid closure type issues if Environment isn't cooperating in this specific context context
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(AppColors.brandPrimary) 
                .padding()
                .background(
                    Circle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 160, height: 160)
                )
            
            VStack(spacing: 12) {
                Text("Welcome to wym")
                    .font(AppTypography.heroRounded(size: 28))
                    .multilineTextAlignment(.center)
                
                Text("Let's set up your profile and financial goals in just a few steps.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.section)
            }
            
            // Login Bypass Link - Only on first page
            NavigationLink(destination: LoginView()) {
                Text("Already have an account? Log In")
                    .font(AppTypography.caption)
                    .foregroundColor(.primary) // Black/White based on theme
                    .padding(.top, 8)
            }
            
            Spacer()
        }
        .onAppear {
            // Request missing permissions
            LocationManager.shared.requestPermission()
            NotificationManager.shared.requestPermission { _ in }
        }
    }
}
