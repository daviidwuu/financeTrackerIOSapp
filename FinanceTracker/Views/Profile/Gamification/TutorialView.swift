import SwiftUI

// MARK: - Tutorial Data Models

struct TutorialStep: Identifiable, Hashable {
    let id = UUID()
    let icon: String           // SF Symbol
    let iconColor: Color
    let title: String
    let description: String
    let animationType: TutorialAnimationType
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TutorialStep, rhs: TutorialStep) -> Bool {
        lhs.id == rhs.id
    }
}

enum TutorialAnimationType {
    case bounce
    case rotate
    case pulse
    case float
}

// MARK: - Tutorial View (Reusable)

struct TutorialView: View {
    let title: String
    let steps: [TutorialStep]
    let accentColor: Color
    let onComplete: (() -> Void)?
    
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0
    
    init(
        title: String,
        steps: [TutorialStep],
        accentColor: Color = .primary,
        onComplete: (() -> Void)? = nil
    ) {
        self.title = title
        self.steps = steps
        self.accentColor = accentColor
        self.onComplete = onComplete
    }
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Content
                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        TutorialStepPage(
                            step: step,
                            stepNumber: index + 1,
                            totalSteps: steps.count
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // Bottom Controls
                VStack(spacing: AppSpacing.element) {
                    // Progress Dots
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentStep ? accentColor : Color.secondary.opacity(0.3))
                                .frame(width: index == currentStep ? 10 : 6, height: index == currentStep ? 10 : 6)
                                .animation(.spring(response: 0.3), value: currentStep)
                        }
                    }
                    .padding(.top, AppSpacing.element)
                    
                    // Navigation Button
                    Button(action: {
                        HapticManager.shared.medium()
                        if currentStep < steps.count - 1 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            onComplete?()
                            dismiss()
                        }
                    }) {
                        Text(currentStep < steps.count - 1 ? "Next" : "Done")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.bottom, 20)
                }
                .background(
                    Color.backgroundPrimary
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: -5)
                )
            }
        }
        .overlayHeader(.navigation(
            title: "Step \(currentStep + 1) of \(steps.count)",
            onBack: { dismiss() },
            backIcon: "xmark"
        ))
    }
}

// MARK: - Tutorial Step Page

struct TutorialStepPage: View {
    let step: TutorialStep
    let stepNumber: Int
    let totalSteps: Int
    
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.section) {
                ScrollOffsetTracker()
                Spacer().frame(height: 60)
                
                // Animated Illustration
                ZStack {
                    // Background circles
                    Circle()
                        .fill(step.iconColor.opacity(0.08))
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.05 : 0.95)
                        .animation(
                            Animation.easeInOut(duration: 3).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Circle()
                        .fill(step.iconColor.opacity(0.12))
                        .frame(width: 140, height: 140)
                    
                    // Icon with animation
                    Image(systemName: step.icon)
                        .font(.system(size: 56))
                        .foregroundColor(step.iconColor)
                        .modifier(AnimationModifier(
                            type: step.animationType,
                            isAnimating: isAnimating
                        ))
                }
                .padding(.top, 20)
                
                // Step Number Badge
                Text("STEP \(stepNumber)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundColor(step.iconColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(step.iconColor.opacity(0.1))
                    .clipShape(Capsule())
                
                // Content
                VStack(spacing: AppSpacing.element) {
                    Text(step.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    Text(step.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppSpacing.margin + 8)
                
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Animation Modifier

struct AnimationModifier: ViewModifier {
    let type: TutorialAnimationType
    let isAnimating: Bool
    
    func body(content: Content) -> some View {
        switch type {
        case .bounce:
            content
                .offset(y: isAnimating ? -8 : 8)
                .animation(
                    Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isAnimating
                )
        case .rotate:
            content
                .rotationEffect(Angle(degrees: isAnimating ? 8 : -8))
                .animation(
                    Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                    value: isAnimating
                )
        case .pulse:
            content
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(
                    Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
        case .float:
            content
                .offset(y: isAnimating ? -6 : 6)
                .rotationEffect(Angle(degrees: isAnimating ? 3 : -3))
                .animation(
                    Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
    }
}
