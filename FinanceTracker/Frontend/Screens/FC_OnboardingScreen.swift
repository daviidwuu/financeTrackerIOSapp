// MARK: - FC_OnboardingScreen.swift
// Frontend layer — Onboarding & Auth screen previews for Figma.
// Sources:
//   Views/Onboarding/WelcomeView.swift
//   Views/Onboarding/LoginView.swift
//   Views/Onboarding/OnboardingView.swift
//   Views/Onboarding/Steps/*.swift
//   Views/Onboarding/PostOnboardingGuideView.swift

import SwiftUI

// MARK: - Welcome Screen

#Preview("Welcome Screen") {
    FC_WelcomeScreenView()
        .previewDisplayName("Welcome")
}

#Preview("Welcome Screen — Dark") {
    FC_WelcomeScreenView()
        .preferredColorScheme(.dark)
        .previewDisplayName("Welcome — Dark")
}

private struct FC_WelcomeScreenView: View {
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / App icon area
                VStack(spacing: AppSpacing.element) {
                    // Concentric circles + icon (IntroStep visual)
                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                            .frame(width: 260, height: 260)
                        Circle()
                            .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                            .frame(width: 200, height: 200)
                        Circle()
                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                            .frame(width: 140, height: 140)
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 88, height: 88)
                            .overlay(
                                Text("w")
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.backgroundPrimary)
                            )
                    }

                    VStack(spacing: AppSpacing.compact) {
                        Text("wym")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Track smarter. Save better.")
                            .font(AppTypography.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                // CTA buttons
                VStack(spacing: AppSpacing.compact) {
                    Button("Get Started") {}
                        .buttonStyle(PrimaryButtonStyle())

                    Button("I have an account") {}
                        .buttonStyle(SecondaryButtonStyle())

                    Text("By continuing you agree to our Terms & Privacy Policy")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.micro)
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, AppSpacing.section)
            }
        }
    }
}

// MARK: - Login Screen

#Preview("Login Screen") {
    FC_LoginScreenView()
        .previewDisplayName("Login")
}

private struct FC_LoginScreenView: View {
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                OverlayHeaderView(
                    mode: .navigation(title: "Welcome back", onBack: {}, backIcon: "chevron.left"),
                    scrollOffset: 0
                )

                ScrollView {
                    VStack(spacing: AppSpacing.element) {
                        Spacer().frame(height: AppSpacing.section)

                        // Fields
                        VStack(spacing: AppSpacing.compact) {
                            // Email
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                TextField("Email", text: .constant("david@example.com"))
                                    .font(AppTypography.body)
                            }
                            .padding(AppSpacing.element)
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)

                            // Password
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                Text("••••••••")
                                    .font(AppTypography.body)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "eye.slash")
                                    .foregroundColor(.secondary)
                            }
                            .padding(AppSpacing.element)
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)

                            // Forgot password
                            HStack {
                                Spacer()
                                Text("Forgot password?")
                                    .font(AppTypography.caption)
                                    .foregroundColor(Color.themeAccent)
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)

                        Spacer().frame(height: AppSpacing.element)

                        Button("Log In") {}
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal, AppSpacing.margin)
                    }
                }
            }
        }
    }
}

// MARK: - Onboarding Steps

#Preview("Onboarding — Step 1: Intro") {
    FC_OnboardingStepView(step: 1)
        .previewDisplayName("Step 1 — Intro")
}

#Preview("Onboarding — Step 2: Name") {
    FC_OnboardingStepView(step: 2)
        .previewDisplayName("Step 2 — Name")
}

#Preview("Onboarding — Step 3: Username") {
    FC_OnboardingStepView(step: 3)
        .previewDisplayName("Step 3 — Username")
}

#Preview("Onboarding — Step 4: Income") {
    FC_OnboardingStepView(step: 4)
        .previewDisplayName("Step 4 — Income")
}

#Preview("Onboarding — Step 5: Categories") {
    FC_OnboardingStepView(step: 5)
        .previewDisplayName("Step 5 — Categories")
}

#Preview("Onboarding — Step 6: Account") {
    FC_OnboardingStepView(step: 6)
        .previewDisplayName("Step 6 — Account")
}

private struct FC_OnboardingStepView: View {
    let step: Int
    private let totalSteps = 6

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Modal header with progress bar
                ModalHeader(
                    title: stepTitle,
                    currentStep: step,
                    totalSteps: totalSteps,
                    onBack: step > 1 ? {} : nil,
                    onClose: {}
                )
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, 16)

                // Step content
                stepContent
                    .frame(maxHeight: .infinity, alignment: .top)

                // Action bar
                VStack(spacing: AppSpacing.compact) {
                    Button(step == totalSteps ? "Create Account" : "Continue") {}
                        .buttonStyle(PrimaryButtonStyle())
                    if step > 1 {
                        Button("Back") {}
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, AppSpacing.element)
                .background(Color.backgroundPrimary)
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case 1: return "Welcome"
        case 2: return "Your name"
        case 3: return "Choose a username"
        case 4: return "Monthly income"
        case 5: return "Your categories"
        case 6: return "Create account"
        default: return ""
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1: introStep
        case 2: nameStep
        case 3: usernameStep
        case 4: incomeStep
        case 5: categoriesStep
        case 6: accountStep
        default: EmptyView()
        }
    }

    // MARK: Step 1 — Intro
    private var introStep: some View {
        VStack(spacing: AppSpacing.section) {
            Spacer().frame(height: AppSpacing.section)
            ZStack {
                Circle().stroke(Color.primary.opacity(0.04), lineWidth: 1).frame(width: 220, height: 220)
                Circle().stroke(Color.primary.opacity(0.07), lineWidth: 1).frame(width: 160, height: 160)
                Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1).frame(width: 110, height: 110)
                Circle()
                    .fill(Color.primary)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Text("w")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(Color.backgroundPrimary)
                    )
            }
            VStack(spacing: AppSpacing.compact) {
                Text("Welcome to wym")
                    .font(AppTypography.titleDisplay)
                    .multilineTextAlignment(.center)
                Text("Track expenses, split bills, and reach your financial goals.")
                    .font(AppTypography.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.large)
            }
        }
        .padding(.horizontal, AppSpacing.margin)
    }

    // MARK: Step 2 — Name
    private var nameStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.element) {
            Spacer().frame(height: AppSpacing.compact)
            Text("What should we call you?")
                .font(AppTypography.headline)
                .padding(.horizontal, AppSpacing.margin)

            HStack {
                TextField("e.g. David", text: .constant("David"))
                    .font(AppTypography.body)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.themeAccent)
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)
        }
    }

    // MARK: Step 3 — Username
    private var usernameStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.element) {
            Spacer().frame(height: AppSpacing.compact)
            Text("Pick a unique username")
                .font(AppTypography.headline)
                .padding(.horizontal, AppSpacing.margin)

            HStack {
                Text("@")
                    .font(AppTypography.body)
                    .foregroundColor(.secondary)
                TextField("username", text: .constant("daviidwuu"))
                    .font(AppTypography.body)
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.themeAccent)
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)

            Text("Minimum 3 characters. Used to find you by friends.")
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, AppSpacing.margin)
        }
    }

    // MARK: Step 4 — Income
    private var incomeStep: some View {
        VStack(spacing: AppSpacing.element) {
            Spacer().frame(height: AppSpacing.section)

            VStack(spacing: AppSpacing.compact) {
                Text("Monthly take-home pay")
                    .font(AppTypography.subheadline)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("4,200")
                        .font(AppTypography.heroInput)
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.margin)
        }
    }

    // MARK: Step 5 — Categories
    private var categoriesStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Spacer().frame(height: AppSpacing.compact)
            Text("Tap to edit any category")
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, AppSpacing.margin)

            ForEach(FC_MockData.categories.filter { $0.type == "expense" }) { cat in
                HStack(spacing: AppSpacing.element) {
                    IconAvatar(systemName: cat.icon, color: cat.color, size: AppSize.avatarList)
                    Text(cat.name)
                        .font(AppTypography.headline)
                    Spacer()
                    Text("$400/mo")
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                .padding(AppSpacing.element)
                .background(Color.cardBackground)
                .cornerRadius(AppRadius.medium)
                .padding(.horizontal, AppSpacing.margin)
            }
        }
    }

    // MARK: Step 6 — Account
    private var accountStep: some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Spacer().frame(height: AppSpacing.compact)
            Text("Create your account")
                .font(AppTypography.headline)
                .padding(.horizontal, AppSpacing.margin)

            // Email field
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.secondary).frame(width: 20)
                TextField("Email address", text: .constant("david@example.com"))
                    .font(AppTypography.body)
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)

            // Password field
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary).frame(width: 20)
                Text("••••••••")
                    .font(AppTypography.body)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "eye.slash").foregroundColor(.secondary)
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            .cornerRadius(AppRadius.medium)
            .padding(.horizontal, AppSpacing.margin)

            Text("By creating an account you agree to our Terms of Service and Privacy Policy.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.margin)
        }
    }
}

// MARK: - Post-Onboarding Guide

#Preview("Post-Onboarding Guide — Step 1") {
    FC_PostOnboardingGuideView(step: 1)
        .previewDisplayName("Guide — Welcome")
}

#Preview("Post-Onboarding Guide — Step 2") {
    FC_PostOnboardingGuideView(step: 2)
        .previewDisplayName("Guide — Back Tap")
}

#Preview("Post-Onboarding Guide — Step 3") {
    FC_PostOnboardingGuideView(step: 3)
        .previewDisplayName("Guide — Widgets")
}

#Preview("Post-Onboarding Guide — Step 4") {
    FC_PostOnboardingGuideView(step: 4)
        .previewDisplayName("Guide — Done")
}

private struct FC_PostOnboardingGuideView: View {
    let step: Int

    private let steps: [(icon: String, title: String, body: String)] = [
        ("hand.wave.fill",       "You're all set!",       "Here are a few tips to get the most out of wym."),
        ("hand.tap.fill",        "Back-tap shortcut",     "Double-tap the back of your iPhone to quickly log a transaction."),
        ("rectangle.stack.fill", "Add a widget",          "Put wym on your Home Screen for instant expense tracking."),
        ("checkmark.circle.fill","You're ready to go",    "Start tracking your spending and hit your financial goals!"),
    ]

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: AppSpacing.section) {
                Spacer()

                let s = steps[step - 1]

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.themeAccent.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: s.icon)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundColor(Color.themeAccent)
                }

                VStack(spacing: AppSpacing.compact) {
                    Text(s.title)
                        .font(AppTypography.titleDisplay)
                        .multilineTextAlignment(.center)
                    Text(s.body)
                        .font(AppTypography.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.section)
                }

                // Step dots
                HStack(spacing: AppSpacing.compact) {
                    ForEach(1...4, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: i == step ? 20 : 8, height: 8)
                    }
                }

                Spacer()

                VStack(spacing: AppSpacing.compact) {
                    Button(step == 4 ? "Let's go!" : "Next") {}
                        .buttonStyle(PrimaryButtonStyle())
                    if step < 4 {
                        Button("Skip") {}
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, AppSpacing.section)
            }
        }
    }
}
