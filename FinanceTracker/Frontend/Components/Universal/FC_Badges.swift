// MARK: - FC_Badges.swift
// Frontend layer — Badge component catalog for Figma.
// Sources:
//   Views/Components/PremiumBadge.swift
//   Views/Components/CircularProgressView.swift

import SwiftUI

// MARK: - Preview Catalog

#Preview("PremiumBadge — All Types & Sizes") {
    // Rounded pill badge shown on premium user profiles
    VStack(spacing: AppSpacing.section) {
        Text("Premium Badge").font(AppTypography.sectionHeader)

        // Small variants
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text("Small").font(AppTypography.headline)
            HStack(spacing: AppSpacing.element) {
                PremiumBadge(size: .small, overrideBadgeType: .king)
                PremiumBadge(size: .small, overrideBadgeType: .pro)
                PremiumBadge(size: .small, overrideBadgeType: .saver)
            }
        }

        // Medium variants
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text("Medium").font(AppTypography.headline)
            HStack(spacing: AppSpacing.element) {
                PremiumBadge(size: .medium, overrideBadgeType: .king)
                PremiumBadge(size: .medium, overrideBadgeType: .pro)
                PremiumBadge(size: .medium, overrideBadgeType: .saver)
            }
        }

        // In-context usage (profile header)
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text("In Profile Context").font(AppTypography.headline)

            VStack(spacing: AppSpacing.compact) {
                Circle()
                    .fill(Color(hex: "#FF9500"))
                    .frame(width: AppSize.avatarHero, height: AppSize.avatarHero)
                    .overlay(
                        Text("D")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )

                Text("David W.")
                    .font(.title2)
                    .fontWeight(.bold)

                PremiumBadge(size: .small, overrideBadgeType: .king)

                Text("@daviidwuu")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
}

#Preview("CircularProgressView") {
    // Ring progress indicator used on the trophy/mission button in HomeView header
    VStack(spacing: AppSpacing.section) {
        Text("Circular Progress").font(AppTypography.sectionHeader)

        // States
        HStack(spacing: AppSpacing.section) {
            VStack(spacing: AppSpacing.compact) {
                ZStack {
                    CircularProgressView(progress: 0.25, lineWidth: 4, color: .blue)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                .frame(width: 44, height: 44)
                Text("25%").font(AppTypography.caption).foregroundColor(.secondary)
            }

            VStack(spacing: AppSpacing.compact) {
                ZStack {
                    CircularProgressView(progress: 0.6, lineWidth: 4, color: .orange)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                .frame(width: 44, height: 44)
                Text("60%").font(AppTypography.caption).foregroundColor(.secondary)
            }

            VStack(spacing: AppSpacing.compact) {
                ZStack {
                    CircularProgressView(progress: 1.0, lineWidth: 4, color: .green)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                .frame(width: 44, height: 44)
                Text("100%").font(AppTypography.caption).foregroundColor(.secondary)
            }
        }

        // Line widths
        HStack(spacing: AppSpacing.section) {
            ForEach([2.0, 4.0, 6.0, 8.0], id: \.self) { lw in
                VStack(spacing: AppSpacing.compact) {
                    CircularProgressView(progress: 0.7, lineWidth: lw, color: .blue)
                        .frame(width: 44, height: 44)
                    Text("\(Int(lw))pt").font(AppTypography.caption).foregroundColor(.secondary)
                }
            }
        }
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
}

#Preview("Streak Pill") {
    // Streak pill as shown in the HomeView overlay header
    HStack(spacing: 4) {
        Image(systemName: "flame.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.orange)
        Text("12")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.primary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Color.cardBackground)
    .clipShape(Capsule())
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
}
