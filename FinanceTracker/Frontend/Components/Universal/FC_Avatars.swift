// MARK: - FC_Avatars.swift
// Frontend layer — Avatar & icon components for Figma.
// Sources:
//   Views/Profile/ProfileAvatar.swift
//   Views/Components/GroupAvatar.swift
//   Views/Components/CategoryIconView.swift
//   DesignSystem.swift (IconAvatar)

import SwiftUI

// MARK: - Preview Catalog

#Preview("ProfileAvatar — All Sizes") {
    // Circular avatar with initial letter. Color is seeded from username.
    VStack(spacing: AppSpacing.section) {
        Text("Profile Avatar").font(AppTypography.sectionHeader)

        HStack(spacing: AppSpacing.element) {
            VStack(spacing: AppSpacing.compact) {
                ProfileAvatar(text: "D", color: Color(hex: "#FF9500"), size: AppSize.avatarHero)
                Text("Hero 86pt").font(AppTypography.caption).foregroundColor(.secondary)
            }
            VStack(spacing: AppSpacing.compact) {
                ProfileAvatar(text: "D", color: Color(hex: "#FF9500"), size: AppSize.avatarList)
                Text("List 48pt").font(AppTypography.caption).foregroundColor(.secondary)
            }
            VStack(spacing: AppSpacing.compact) {
                ProfileAvatar(text: "D", color: Color(hex: "#FF9500"), size: AppSize.avatarMedium)
                Text("Med 40pt").font(AppTypography.caption).foregroundColor(.secondary)
            }
            VStack(spacing: AppSpacing.compact) {
                ProfileAvatar(text: "D", color: Color(hex: "#FF9500"), size: AppSize.avatarSmall)
                Text("Sm 32pt").font(AppTypography.caption).foregroundColor(.secondary)
            }
        }

        Text("Color Variants").font(AppTypography.headline)
        HStack(spacing: AppSpacing.compact) {
            ForEach(["#007AFF", "#34C759", "#FF9500", "#FF2D55", "#AF52DE", "#5856D6"], id: \.self) { hex in
                ProfileAvatar(text: "A", color: Color(hex: hex), size: AppSize.avatarList)
            }
        }
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
}

#Preview("GroupAvatar — All Gradients") {
    // Circular avatar with gradient fill + SF Symbol. Used for groups.
    VStack(spacing: AppSpacing.section) {
        Text("Group Avatar").font(AppTypography.sectionHeader)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4),
                  spacing: AppSpacing.element) {
            ForEach(Color.GradientTheme.allThemes) { theme in
                VStack(spacing: AppSpacing.micro) {
                    GroupAvatar(icon: "airplane", color: theme.colors.first?.toHex() ?? "007AFF", size: AppSize.avatarList)
                    Text(theme.name).font(AppTypography.caption).foregroundColor(.secondary)
                }
            }
        }

        Text("Icon Variants").font(AppTypography.headline)
        HStack(spacing: AppSpacing.element) {
            GroupAvatar(icon: "house.fill",      color: "#34C759", size: AppSize.avatarList)
            GroupAvatar(icon: "fork.knife",      color: "#FF9500", size: AppSize.avatarList)
            GroupAvatar(icon: "gamecontroller",  color: "#AF52DE", size: AppSize.avatarList)
            GroupAvatar(icon: "heart.fill",      color: "#FF2D55", size: AppSize.avatarList)
        }

        Text("Sizes").font(AppTypography.headline)
        HStack(spacing: AppSpacing.element) {
            GroupAvatar(icon: "airplane", color: "#007AFF", size: AppSize.avatarHero)
            GroupAvatar(icon: "airplane", color: "#007AFF", size: AppSize.avatarList)
            GroupAvatar(icon: "airplane", color: "#007AFF", size: AppSize.avatarMedium)
            GroupAvatar(icon: "airplane", color: "#007AFF", size: AppSize.avatarSmall)
        }
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
}

#Preview("IconAvatar — Category Circles") {
    // Tinted circle + SF Symbol. Used for category rows, transaction rows.
    VStack(spacing: AppSpacing.section) {
        Text("Icon Avatar").font(AppTypography.sectionHeader)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4),
                  spacing: AppSpacing.element) {
            ForEach(FC_MockData.categories) { cat in
                VStack(spacing: AppSpacing.micro) {
                    IconAvatar(systemName: cat.icon, color: cat.color, size: AppSize.avatarList)
                    Text(cat.name.components(separatedBy: " ").first ?? cat.name)
                        .font(AppTypography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }

        Text("Sizes").font(AppTypography.headline)
        HStack(spacing: AppSpacing.element) {
            IconAvatar(systemName: "fork.knife", color: .orange, size: AppSize.avatarHero)
            IconAvatar(systemName: "fork.knife", color: .orange, size: AppSize.avatarList)
            IconAvatar(systemName: "fork.knife", color: .orange, size: AppSize.avatarMedium)
            IconAvatar(systemName: "fork.knife", color: .orange, size: AppSize.avatarSmall)
        }
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
}

#Preview("CategoryIconView — Standalone (resolved)") {
    // Figma-friendly replica of CategoryIconView using direct parameters.
    // Real CategoryIconView uses @EnvironmentObject; this shows the resolved output.
    VStack(spacing: AppSpacing.section) {
        Text("Category Icons").font(AppTypography.sectionHeader)

        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5),
                  spacing: AppSpacing.element) {
            ForEach(FC_MockData.categories) { cat in
                VStack(spacing: AppSpacing.micro) {
                    ZStack {
                        Circle()
                            .fill(cat.color.opacity(0.1))
                            .frame(width: 48, height: 48)
                        Image(systemName: cat.icon)
                            .font(.system(size: 20))
                            .foregroundColor(cat.color)
                    }
                    Text(cat.name.components(separatedBy: " ").first ?? cat.name)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
}
