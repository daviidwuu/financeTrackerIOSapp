// MARK: - FC_Headers.swift
// Frontend layer — Header component catalog for Figma.
// Sources:
//   Views/Components/OverlayHeaderView.swift
//   Views/Components/ModalHeader.swift
//   Views/Components/DetailHeaderView.swift

import SwiftUI

// MARK: - OverlayHeaderView Previews

#Preview("OverlayHeader — Root Mode (Home / Wallet / Social)") {
    // Used at the top of every main tab screen.
    // Appears transparent when at top, blurs on scroll.
    NavigationStack {
        ZStack(alignment: .top) {
            Color.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.element) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 80)

                    // Simulate content cards
                    ForEach(0..<12) { i in
                        HStack {
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(Color.cardBackground)
                                .frame(height: 60)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
            }
            .coordinateSpace(name: "overlayHeaderScroll")

            OverlayHeaderView(
                mode: .root(title: "Home", subtitle: nil,
                            trailing: AnyView(
                                HStack(spacing: AppSpacing.compact) {
                                    // Streak pill
                                    HStack(spacing: 4) {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.orange)
                                        Text("12")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.cardBackground)
                                    .clipShape(Capsule())

                                    // Notifications
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                                        .background(Color.primary.opacity(0.05))
                                        .clipShape(Circle())

                                    // Profile avatar
                                    ProfileAvatar(text: "D", color: Color(hex: "#FF9500"), size: 36)
                                }
                            )
                           ),
                scrollOffset: 0
            )
        }
        .navigationBarHidden(true)
    }
    .previewDisplayName("Root — Home (no scroll)")
}

#Preview("OverlayHeader — Root Mode (Welcome style)") {
    // isWelcomeStyle = true: small label on top, large name below
    NavigationStack {
        ZStack(alignment: .top) {
            Color.backgroundPrimary.ignoresSafeArea()
            ScrollView {
                Spacer().frame(height: 80)
            }
            OverlayHeaderView(
                mode: .root(
                    title: "Good morning,",
                    subtitle: "David",
                    isWelcomeStyle: true
                ),
                scrollOffset: 0
            )
        }
        .navigationBarHidden(true)
    }
    .previewDisplayName("Root — Welcome Style")
}

#Preview("OverlayHeader — Navigation Mode (Settings / Detail)") {
    // Used for settings screens and sub-screens pushed via NavigationStack.
    NavigationStack {
        ZStack(alignment: .top) {
            Color.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.element) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 80)
                    ForEach(0..<15) { _ in
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(Color.cardBackground)
                            .frame(height: 52)
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
            }
            .coordinateSpace(name: "overlayHeaderScroll")

            OverlayHeaderView(
                mode: .navigation(title: "Account Settings", onBack: {}),
                scrollOffset: 0
            )
        }
        .navigationBarHidden(true)
    }
    .previewDisplayName("Navigation — Settings")
}

#Preview("OverlayHeader — Navigation Mode (Sheet / xmark)") {
    NavigationStack {
        ZStack(alignment: .top) {
            Color.backgroundPrimary.ignoresSafeArea()
            ScrollView {
                Spacer().frame(height: 80)
            }
            .coordinateSpace(name: "overlayHeaderScroll")
            OverlayHeaderView(
                mode: .navigation(title: "Profile", onBack: {}, backIcon: "xmark"),
                scrollOffset: 0
            )
        }
        .navigationBarHidden(true)
    }
    .previewDisplayName("Navigation — xmark (sheet)")
}

// MARK: - ModalHeader Previews

#Preview("ModalHeader — All Steps") {
    // Multi-step modal header with progress bar.
    // Used in: AddTransactionView (3 steps), OnboardingView (6 steps),
    //          GroupCreationWizardView (3 steps), SplitConfigurationView (2 steps).
    VStack(spacing: 0) {
        Text("ModalHeader").font(AppTypography.sectionHeader)
            .padding()

        ForEach(1...3, id: \.self) { step in
            VStack(spacing: AppSpacing.compact) {
                Text("Step \(step) of 3").font(AppTypography.caption).foregroundColor(.secondary)
                ModalHeader(title: "Add Transaction", currentStep: step, totalSteps: 3,
                            onBack: step > 1 ? {} : nil, onClose: {})
            }
            Divider()
        }

        // Close-only (no back button)
        VStack(spacing: AppSpacing.compact) {
            Text("Single-step (xmark only)").font(AppTypography.caption).foregroundColor(.secondary)
            ModalHeader(title: "Select Currency", currentStep: nil, totalSteps: nil,
                        onBack: nil, onClose: {})
        }
    }
    .background(Color.backgroundPrimary)
}

// MARK: - DetailHeaderView Previews

#Preview("DetailHeaderView — Transaction Detail") {
    // Full-width colored header used in TransactionDetailView, GroupDetailView, FriendDetailView.
    // Background fills the entire top area including safe area.
    VStack(spacing: 0) {
        DetailHeaderView(
            title: "Food & Drink",
            subtitle: "Today at 12:34 PM",
            onBack: {},
            backgroundColor: Color(hex: "#FF9500"),
            textColor: .white,
            avatar: {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: AppSize.avatarHero, height: AppSize.avatarHero)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                    )
            },
            actions: {
                HStack(spacing: AppSpacing.element) {
                    Button("Edit") {}
                        .buttonStyle(SmallSecondaryButtonStyle())
                    Button("Delete") {}
                        .foregroundColor(.white)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        )

        Spacer()
    }
    .background(Color.backgroundPrimary)
    .ignoresSafeArea(edges: .top)
    .previewDisplayName("Transaction Detail Header")
}

#Preview("DetailHeaderView — Group Detail") {
    VStack(spacing: 0) {
        DetailHeaderView(
            title: "Hawaii Trip",
            subtitle: "4 members",
            onBack: {},
            backgroundColor: Color(hex: "#007AFF"),
            textColor: .white,
            avatar: {
                GroupAvatar(icon: "airplane", color: "#007AFF", size: AppSize.avatarHero)
            },
            actions: {
                HStack(spacing: AppSpacing.element) {
                    Button("Members") {}
                        .foregroundColor(.white)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    Button("Settle Up") {}
                        .foregroundColor(.white)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        )
        Spacer()
    }
    .background(Color.backgroundPrimary)
    .ignoresSafeArea(edges: .top)
    .previewDisplayName("Group Detail Header")
}

#Preview("DetailHeaderView — Friend Detail") {
    VStack(spacing: 0) {
        DetailHeaderView(
            title: "Alex R.",
            subtitle: "@alexr",
            onBack: {},
            backgroundColor: Color(hex: "#5856D6"),
            textColor: .white,
            avatar: {
                ProfileAvatar(text: "A", color: Color(hex: "#5856D6"), size: AppSize.avatarHero)
            },
            actions: {
                HStack(spacing: AppSpacing.element) {
                    Button("Settle Up") {}
                        .foregroundColor(.white)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        )
        Spacer()
    }
    .background(Color.backgroundPrimary)
    .ignoresSafeArea(edges: .top)
    .previewDisplayName("Friend Detail Header")
}
