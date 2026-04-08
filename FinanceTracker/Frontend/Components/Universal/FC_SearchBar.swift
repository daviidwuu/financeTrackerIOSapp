// MARK: - FC_SearchBar.swift
// Frontend layer — SearchBar component catalog for Figma.
// Source: Views/Components/SearchBar.swift

import SwiftUI

#Preview("SearchBar — All States") {
    // Capsule search field: magnifier + text field + clear/loading accessory
    VStack(spacing: AppSpacing.element) {
        Text("SearchBar").font(AppTypography.sectionHeader)

        // Empty state
        VStack(alignment: .leading, spacing: AppSpacing.micro) {
            Text("Empty").font(AppTypography.caption).foregroundColor(.secondary)
            SearchBar(text: .constant(""), placeholder: "Search friends...")
        }

        // With text
        VStack(alignment: .leading, spacing: AppSpacing.micro) {
            Text("With text + clear button").font(AppTypography.caption).foregroundColor(.secondary)
            SearchBar(text: .constant("Alex"))
        }

        // Loading
        VStack(alignment: .leading, spacing: AppSpacing.micro) {
            Text("Loading").font(AppTypography.caption).foregroundColor(.secondary)
            SearchBar(text: .constant("alex"), isLoading: true)
        }

        // Different placeholders
        VStack(alignment: .leading, spacing: AppSpacing.micro) {
            Text("Transaction search").font(AppTypography.caption).foregroundColor(.secondary)
            SearchBar(text: .constant(""), placeholder: "Search transactions...")
        }
    }
    .padding(AppSpacing.margin)
    .background(Color.backgroundPrimary)
}
