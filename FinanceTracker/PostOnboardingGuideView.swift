import SwiftUI

struct PostOnboardingGuideView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var currentStep = 1
    @State private var direction: Edge = .trailing
    
    var body: some View {
        ZStack {
            // Background
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar
                HStack(spacing: 4) {
                    ForEach(1...4, id: \.self) { step in
                        Capsule()
                            .fill(step <= currentStep ? Color.white : Color.gray.opacity(0.2))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
                
                // Content
                ZStack(alignment: .top) {
                    Group {
                        switch currentStep {
                        case 1: WelcomeGuideStep()
                        case 2: BackTapGuideStep()
                        case 3: WidgetsGuideStep()
                        case 4: CompletionGuideStep()
                        default: EmptyView()
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: direction),
                        removal: .move(edge: direction == .leading ? .trailing : .leading)
                    ))
                }
                .frame(maxHeight: .infinity, alignment: .top)
                
                Spacer()
                
                // Navigation Buttons
                HStack(spacing: 16) {
                    if currentStep > 1 && currentStep < 4 {
                        Button(action: prevStep) {
                            Image(systemName: "arrow.left")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(width: 50, height: 50)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Circle())
                        }
                    }
                    
                    Button(action: nextStep) {
                        Text(currentStep == 4 ? "Get Started" : "Next")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(16)
                    .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(24)
                .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.9))
            }
            
            // Skip Button (Top Right)
            if currentStep < 4 {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: completeGuide) {
                            Text("Skip")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func nextStep() {
        if currentStep < 4 {
            direction = .trailing
            HapticManager.shared.light()
            withAnimation { currentStep += 1 }
        } else {
            HapticManager.shared.success()
            completeGuide()
        }
    }
    
    private func prevStep() {
        if currentStep > 1 {
            direction = .leading
            HapticManager.shared.light()
            withAnimation { currentStep -= 1 }
        }
    }
    
    private func completeGuide() {
        appState.markPostOnboardingGuideAsSeen(userId: appState.currentUserId)
        dismiss()
    }
}

// MARK: - Step Views

struct WelcomeGuideStep: View {
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .scaleEffect(animate ? 1.1 : 1.0)
                    .opacity(animate ? 0.5 : 0.8)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .scaleEffect(animate ? 1.0 : 0.8)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
            
            VStack(spacing: 16) {
                Text("🎉 All Set!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("Your account is ready. Let's show you some powerful features to get the most out of Finance Tracker.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

struct BackTapGuideStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 70))
                .foregroundColor(.blue)
                .padding(.bottom, 12)
            
            Text("Quick Logging with Back Tap")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            Text("Log expenses in seconds without even opening the app")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(number: 1, text: "Open Settings → Accessibility → Touch")
                InstructionRow(number: 2, text: "Select \"Back Tap\"")
                InstructionRow(number: 3, text: "Choose \"Double Tap\" or \"Triple Tap\"")
                InstructionRow(number: 4, text: "Select \"Log Transaction\" from Shortcuts")
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
            
            Spacer()
        }
    }
}

struct WidgetsGuideStep: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.purple)
                    
                    Text("Stay On Top with Widgets")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    
                    Text("Add widgets to your home and lock screens for instant budget tracking")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    WidgetCard(
                        icon: "square.grid.2x2",
                        title: "Home Screen Widgets",
                        description: "Daily budget tracker and monthly overview",
                        color: .blue
                    )
                    
                    WidgetCard(
                        icon: "lock.fill",
                        title: "Lock Screen Widget",
                        description: "Quick daily spending summary at a glance",
                        color: .green
                    )
                    
                    WidgetCard(
                        icon: "plus.circle.fill",
                        title: "Quick Log Widget",
                        description: "One-tap to add new transactions",
                        color: .orange
                    )
                }
                .padding(.horizontal, 24)
                
                VStack(spacing: 12) {
                    Text("How to Add")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        InstructionRow(number: 1, text: "Long press on home screen")
                        InstructionRow(number: 2, text: "Tap the \"+\" button")
                        InstructionRow(number: 3, text: "Search \"Finance Tracker\"")
                        InstructionRow(number: 4, text: "Choose your widget size")
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                
                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
    }
}

struct CompletionGuideStep: View {
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
                .scaleEffect(animate ? 1.2 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        animate = true
                    }
                }
            
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("Start tracking your finances and building better money habits today.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}

// MARK: - Helper Views

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(.body, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

struct WidgetCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)
                .frame(width: 60, height: 60)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    PostOnboardingGuideView()
        .environmentObject(AppState.shared)
}
