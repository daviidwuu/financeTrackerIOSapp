// MARK: - FC_Buttons.swift
// Frontend layer — Button component catalog for Figma.
// Re-exports existing button styles with full preview coverage.
// Source: Views/Components/ButtonStyles.swift

import SwiftUI

// MARK: - Preview Catalog

#Preview("Primary Button — All States") {
    VStack(spacing: AppSpacing.element) {
        // Enabled
        Button("Continue") {}
            .buttonStyle(PrimaryButtonStyle())

        // Loading
        Button("Saving...") {}
            .buttonStyle(PrimaryButtonStyle(isLoading: true))

        // Disabled
        Button("Continue") {}
            .buttonStyle(PrimaryButtonStyle())
            .disabled(true)
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
    .previewDisplayName("Primary Button")
}

#Preview("Secondary Button — All States") {
    VStack(spacing: AppSpacing.element) {
        // Enabled
        Button("Go Back") {}
            .buttonStyle(SecondaryButtonStyle())

        // Disabled
        Button("Go Back") {}
            .buttonStyle(SecondaryButtonStyle())
            .disabled(true)
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
    .previewDisplayName("Secondary Button")
}

#Preview("Small Buttons") {
    VStack(spacing: AppSpacing.element) {
        HStack(spacing: AppSpacing.element) {
            Button("Subscribe") {}
                .buttonStyle(SmallPrimaryButtonStyle())

            Button("Edit profile") {}
                .buttonStyle(SmallSecondaryButtonStyle())
        }

        HStack(spacing: AppSpacing.element) {
            Button("Subscribe") {}
                .buttonStyle(SmallPrimaryButtonStyle())
                .disabled(true)

            Button("Edit profile") {}
                .buttonStyle(SmallSecondaryButtonStyle())
                .disabled(true)
        }
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
    .previewDisplayName("Small Buttons")
}

#Preview("Button Pair — Primary + Secondary") {
    // Canonical CTA layout used in every wizard/modal action bar
    VStack(spacing: AppSpacing.compact) {
        Button("Continue") {}
            .buttonStyle(PrimaryButtonStyle())

        Button("Go Back") {}
            .buttonStyle(SecondaryButtonStyle())
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
    .previewDisplayName("Button Pair")
}

#Preview("Icon Buttons (circle)") {
    // Circular icon buttons as used in overlay headers
    HStack(spacing: AppSpacing.element) {
        // Back / close button
        Button {} label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)

        // Chevron back
        Button {} label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)

        // Bell
        Button {} label: {
            Image(systemName: "bell.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)

        // Ellipsis menu
        Button {} label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                .background(Color.primary.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
    .previewDisplayName("Icon Buttons")
}

#Preview("Accept / Decline Buttons") {
    // Used in friend requests and pending invitations
    AcceptDeclineButtons(onAccept: {}, onDecline: {})
        .padding(AppSpacing.margin)
        .background(Color.backgroundPrimary)
        .previewDisplayName("Accept / Decline")
}

#Preview("Dashed Add Button") {
    // Used in group creation wizard member list
    DashedAddButton(label: "Add member", action: {})
        .appCardStyle()
        .padding(AppSpacing.margin)
        .background(Color.backgroundPrimary)
        .previewDisplayName("Dashed Add")
}
