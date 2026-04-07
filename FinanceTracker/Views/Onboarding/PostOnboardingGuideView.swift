import SwiftUI

struct PostOnboardingGuideView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var currentStep = 1
    @State private var direction: Edge = .trailing

    init(initialStep: Int = 1) {
        _currentStep = State(initialValue: initialStep)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar
                HStack(spacing: AppSpacing.micro) {
                    ForEach(1...4, id: \.self) { step in
                        Capsule()
                            .fill(step <= currentStep ? Color.white : Color.secondary.opacity(0.2))
                            .frame(height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.margin)
                .padding(.bottom, AppSpacing.section + AppSpacing.compact)
                
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
                HStack(spacing: AppSpacing.element) {
                    if currentStep > 1 && currentStep < 4 {
                        Button(action: {
                            HapticManager.shared.light()
                            prevStep()
                        }) {
                            Image(systemName: "arrow.left")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(width: 50, height: 50)
                                .background(Color.cardBackground)
                                .clipShape(Circle())
                        }
                    }

                    Button(action: {
                        HapticManager.shared.light()
                        nextStep()
                    }) {
                        Text(currentStep == 4 ? "Get Started" : "Next")
                            .font(AppTypography.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.primary)
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .clipShape(Capsule())
                    .shadow(color: .white.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(AppSpacing.large)
                .background((colorScheme == .dark ? Color.black : Color.white).opacity(0.9))
            }
            
            // Skip Button (Top Right)
            if currentStep < 4 {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            HapticManager.shared.light()
                            completeGuide()
                        }) {
                            Text("Skip")
                                .font(AppTypography.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, AppSpacing.large)
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
            withAnimation { currentStep += 1 }
        } else {
            HapticManager.shared.success()
            completeGuide()
        }
    }
    
    private func prevStep() {
        if currentStep > 1 {
            direction = .leading
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
                    .fill(AppColors.functionalIncome.opacity(0.2))
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
            
            VStack(spacing: AppSpacing.element) {
                Text("🎉 All Set!")
                    .font(AppTypography.heroRounded(size: 32))
                
                Text("Your account is ready. Let's show you some powerful features to get the most out of wym.")
                    .font(AppTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.section)
            }

            Spacer()
        }
    }
}

struct BackTapGuideStep: View {
    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Spacer()
            
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 70))
                .foregroundColor(.blue)
                .padding(.bottom, AppSpacing.compact)

            Text("Quick Logging with Back Tap")
                .font(AppTypography.heroRounded(size: 28))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.large)

            Text("Log expenses in seconds without even opening the app")
                .font(AppTypography.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.section)

            VStack(alignment: .leading, spacing: AppSpacing.element) {
                InstructionRow(number: 1, text: "Open Settings → Accessibility → Touch")
                InstructionRow(number: 2, text: "Select \"Back Tap\"")
                InstructionRow(number: 3, text: "Choose \"Double Tap\" or \"Triple Tap\"")
                InstructionRow(number: 4, text: "Select \"Log Transaction\" from Shortcuts")
            }
            .padding(.horizontal, AppSpacing.section)
            .padding(.top, AppSpacing.compact)

            Spacer()
        }
    }
}

struct WidgetsGuideStep: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: AppSpacing.element) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.purple)
                    
                    Text("Stay On Top with Widgets")
                        .font(AppTypography.heroRounded(size: 28))
                        .multilineTextAlignment(.center)
                    
                    Text("Add widgets to your home and lock screens for instant budget tracking")
                        .font(AppTypography.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.section)
                }
                .padding(.top, AppSpacing.section + AppSpacing.compact)

                VStack(spacing: AppSpacing.margin) {
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
                .padding(.horizontal, AppSpacing.large)

                VStack(spacing: AppSpacing.compact) {
                    Text("How to Add")
                        .font(AppTypography.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.compact) {
                        InstructionRow(number: 1, text: "Long press on home screen")
                        InstructionRow(number: 2, text: "Tap the \"+\" button")
                        InstructionRow(number: 3, text: "Search \"wym\"")
                        InstructionRow(number: 4, text: "Choose your widget size")
                    }
                }
                .padding(.horizontal, AppSpacing.section)
                .padding(.vertical, AppSpacing.element)
                
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
            
            VStack(spacing: AppSpacing.element) {
                Text("You're All Set!")
                    .font(AppTypography.heroRounded(size: 32))
                
                Text("Start tracking your finances and building better money habits today.")
                    .font(AppTypography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.section)
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
        HStack(alignment: .top, spacing: AppSpacing.compact) {
            Text("\(number)")
                .font(AppTypography.heroRounded(size: 16))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(AppColors.brandPrimary)
                .clipShape(Circle())
            
            Text(text)
                .font(AppTypography.body)
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
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(AppTypography.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}

#Preview {
    PostOnboardingGuideView()
        .environmentObject(AppState.shared)
}
