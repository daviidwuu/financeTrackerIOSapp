import SwiftUI

struct WelcomeView: View {
    @State private var showOnboarding = false
    @State private var showLogin = false
    @State private var animateLogo = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                (colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Logo & Title
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 120, height: 120)
                                .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 50))
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.black)
                                .scaleEffect(animateLogo ? 1.0 : 0.8)
                                .opacity(animateLogo ? 1.0 : 0.0)
                        }
                        
                        VStack(spacing: 12) {
                            Text("Finance Tracker")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Master your money with ease")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .opacity(animateLogo ? 1.0 : 0.0)
                        .offset(y: animateLogo ? 0 : 20)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        Button(action: { showOnboarding = true }) {
                            Text("Get Started")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        
                        Button(action: { showLogin = true }) {
                            Text("I already have an account")
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .opacity(animateLogo ? 1.0 : 0.0)
                    .offset(y: animateLogo ? 0 : 20)
                }
            }
            .navigationDestination(isPresented: $showOnboarding) {
                OnboardingView()
            }
            .navigationDestination(isPresented: $showLogin) {
                LoginView()
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    animateLogo = true
                }
            }
        }
    }
}

#Preview {
    WelcomeView()
}
