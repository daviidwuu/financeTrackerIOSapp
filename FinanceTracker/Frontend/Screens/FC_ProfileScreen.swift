// MARK: - FC_ProfileScreen.swift
// Frontend layer — Profile sheet screen preview for Figma.
// Source: Views/Profile/ProfileView.swift
//
// Shown as a sheet from HomeView when the user taps their avatar.

import SwiftUI

#Preview("Profile — Premium User") {
    FC_ProfileScreenView(isPremium: true)
        .previewDisplayName("Profile — Premium")
}

#Preview("Profile — Free User") {
    FC_ProfileScreenView(isPremium: false)
        .previewDisplayName("Profile — Free")
}

#Preview("Profile — Dark Mode") {
    FC_ProfileScreenView(isPremium: true)
        .preferredColorScheme(.dark)
        .previewDisplayName("Profile — Dark")
}

// MARK: - Static View Implementation

private struct FC_ProfileScreenView: View {
    let isPremium: Bool
    @Environment(\.colorScheme) var colorScheme

    private let user = FC_MockData.userProfile

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.element) {
                        ScrollOffsetTracker()
                        Spacer().frame(height: 80)

                        // MARK: Profile Header
                        profileHeader

                        // MARK: Subscription Section
                        MenuSection("Subscription") {
                            menuRow(icon: "crown.fill", title: "Subscription",
                                    subtitle: isPremium ? "Active — wym king" : "Upgrade to premium",
                                    color: Color(hex: "#F5A623"))
                        }

                        // MARK: Preferences
                        MenuSection("Preferences") {
                            menuRow(icon: "paintbrush.fill",  title: "Appearance",            subtitle: "System",      color: .blue)
                            Divider().padding(.leading, 60)
                            menuRow(icon: "bell.fill",        title: "Notifications",          subtitle: "On",          color: .red)
                            Divider().padding(.leading, 60)
                            menuRow(icon: "location.fill",    title: "Location",               subtitle: "While using", color: .green)
                            Divider().padding(.leading, 60)
                            menuControlRow(icon: "iphone.radiowaves.left.and.right", title: "Haptic Feedback", isOn: true, color: .purple)
                            Divider().padding(.leading, 60)
                            menuControlRow(icon: "hand.raised.fill", title: "Privacy Mode", isOn: false, color: .gray)
                        }

                        // MARK: Support & About
                        MenuSection("Support & About") {
                            menuRow(icon: "questionmark.circle.fill", title: "Help Center",  subtitle: nil, color: .blue)
                            Divider().padding(.leading, 60)
                            menuRow(icon: "book.fill",                title: "Guides",        subtitle: nil, color: .orange)
                            Divider().padding(.leading, 60)
                            menuRow(icon: "doc.text.fill",            title: "Privacy Policy", subtitle: nil, color: .gray)
                            Divider().padding(.leading, 60)
                            menuRow(icon: "doc.text.fill",            title: "Terms of Service", subtitle: nil, color: .gray)
                        }

                        // MARK: Gamification
                        MenuSection("Achievements") {
                            menuRow(icon: "trophy.fill",     title: "Mission Hub",  subtitle: "2,450 pts", color: Color(hex: "#F5A623"))
                            Divider().padding(.leading, 60)
                            menuRow(icon: "rosette",         title: "Rewards",      subtitle: nil,          color: .purple)
                        }

                        // MARK: Logout
                        MenuSection(nil) {
                            Button {} label: {
                                HStack {
                                    Spacer()
                                    Text("Log Out")
                                        .font(AppTypography.headline)
                                        .foregroundColor(Color.functionalError)
                                    Spacer()
                                }
                                .padding(.vertical, AppRadius.rowVertical)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Spacer().frame(height: AppSpacing.section)
                    }
                }

                // Overlay header (xmark to dismiss sheet)
                OverlayHeaderView(
                    mode: .navigation(title: "Profile", onBack: {}, backIcon: "xmark"),
                    scrollOffset: 0
                )
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: AppSpacing.element) {
            // Avatar
            Circle()
                .fill(user.color)
                .frame(width: AppSize.avatarHero, height: AppSize.avatarHero)
                .overlay(
                    Text(user.initial)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

            VStack(spacing: 4) {
                Text(user.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if isPremium {
                    PremiumBadge(size: .small, overrideBadgeType: .king)
                        .padding(.top, 2)
                }

                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, isPremium ? 2 : 0)
            }

            // Edit profile button
            Text("Edit profile")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .padding(.vertical, 10)
                .padding(.horizontal, AppSpacing.margin)
                .background(colorScheme == .dark ? Color.white : Color.black)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.large)
    }

    // MARK: - Row Helpers

    private func menuRow(icon: String, title: String, subtitle: String?, color: Color) -> some View {
        HStack(spacing: AppSpacing.element) {
            RoundedRectangle(cornerRadius: AppRadius.xSmall)
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            Text(title)
                .font(AppTypography.body)
                .foregroundColor(.primary)

            Spacer()

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.vertical, AppRadius.rowVertical)
        .padding(.horizontal, AppSpacing.element)
    }

    private func menuControlRow(icon: String, title: String, isOn: Bool, color: Color) -> some View {
        HStack(spacing: AppSpacing.element) {
            RoundedRectangle(cornerRadius: AppRadius.xSmall)
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                )

            Text(title)
                .font(AppTypography.body)
                .foregroundColor(.primary)

            Spacer()

            // Monochromatic toggle visual replica
            Capsule()
                .fill(isOn ? Color.primary : Color.secondaryCardBackground)
                .frame(width: 51, height: 31)
                .overlay(
                    Circle()
                        .fill(isOn ? Color.backgroundPrimary : Color.white)
                        .frame(width: 27, height: 27)
                        .offset(x: isOn ? 10 : -10)
                )
        }
        .padding(.vertical, AppRadius.rowVertical)
        .padding(.horizontal, AppSpacing.element)
    }
}
