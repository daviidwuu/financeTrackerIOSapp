// MARK: - FC_ComponentCatalog.swift
// Frontend layer — Master component catalog for Figma import.
//
// This single file previews every reusable component in one scrollable view.
// Use it with Xcode's canvas (Editor → Canvas) or the Figma iOS plugin to
// get a complete picture of the design system at a glance.
//
// Individual component files (FC_Buttons, FC_Avatars, etc.) contain more
// detailed per-state previews; this catalog is the "overview" view.

import SwiftUI

// MARK: - Full Catalog Preview

#Preview("Component Catalog — Light") {
    FC_ComponentCatalogView()
}

#Preview("Component Catalog — Dark") {
    FC_ComponentCatalogView()
        .preferredColorScheme(.dark)
}

// MARK: - View

struct FC_ComponentCatalogView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {

                catalogHeader("wym — Component Catalog")

                // MARK: Buttons
                catalogSection("Buttons") {
                    VStack(spacing: AppSpacing.compact) {
                        Button("Primary Action") {}
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Secondary Action") {}
                            .buttonStyle(SecondaryButtonStyle())
                        HStack(spacing: AppSpacing.compact) {
                            Button("Small Primary") {}
                                .buttonStyle(SmallPrimaryButtonStyle())
                            Button("Small Secondary") {}
                                .buttonStyle(SmallSecondaryButtonStyle())
                        }
                        HStack(spacing: AppSpacing.compact) {
                            // Icon-only circle buttons
                            ForEach(["xmark", "chevron.left", "bell.fill", "plus", "ellipsis"], id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: AppSize.iconButton, height: AppSize.iconButton)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(Circle())
                            }
                        }
                        AcceptDeclineButtons(onAccept: {}, onDecline: {})
                    }
                }

                // MARK: Avatars
                catalogSection("Avatars") {
                    VStack(spacing: AppSpacing.element) {
                        // Profile avatars
                        HStack(spacing: AppSpacing.element) {
                            Text("Profile").font(AppTypography.caption).foregroundColor(.secondary).frame(width: 60)
                            ProfileAvatar(text: "D", color: Color(hex: "#FF9500"), size: AppSize.avatarHero)
                            ProfileAvatar(text: "D", color: Color(hex: "#FF9500"), size: AppSize.avatarList)
                            ProfileAvatar(text: "D", color: Color(hex: "#FF9500"), size: AppSize.avatarMedium)
                            ProfileAvatar(text: "D", color: Color(hex: "#FF9500"), size: AppSize.avatarSmall)
                        }

                        // Group avatars
                        HStack(spacing: AppSpacing.element) {
                            Text("Group").font(AppTypography.caption).foregroundColor(.secondary).frame(width: 60)
                            GroupAvatar(icon: "airplane",   color: "#007AFF", size: AppSize.avatarList)
                            GroupAvatar(icon: "house.fill", color: "#34C759", size: AppSize.avatarList)
                            GroupAvatar(icon: "fork.knife", color: "#FF9500", size: AppSize.avatarList)
                        }

                        // Category icon avatars
                        HStack(spacing: AppSpacing.element) {
                            Text("Category").font(AppTypography.caption).foregroundColor(.secondary).frame(width: 60)
                            ForEach(FC_MockData.categories.prefix(4)) { cat in
                                IconAvatar(systemName: cat.icon, color: cat.color, size: AppSize.avatarList)
                            }
                        }
                    }
                }

                // MARK: Badges & Indicators
                catalogSection("Badges & Indicators") {
                    VStack(spacing: AppSpacing.element) {
                        HStack(spacing: AppSpacing.element) {
                            PremiumBadge(size: .small, overrideBadgeType: .king)
                            PremiumBadge(size: .small, overrideBadgeType: .pro)
                            PremiumBadge(size: .small, overrideBadgeType: .saver)
                            PremiumBadge(size: .medium, overrideBadgeType: .king)
                        }

                        // Streak pill
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(.orange)
                            Text("12").font(.system(size: 13, weight: .bold))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.cardBackground)
                        .clipShape(Capsule())

                        // Circular progress
                        HStack(spacing: AppSpacing.section) {
                            ForEach([0.25, 0.6, 1.0], id: \.self) { p in
                                ZStack {
                                    CircularProgressView(progress: p, lineWidth: 4, color: .blue)
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                .frame(width: 40, height: 40)
                            }
                        }
                    }
                }

                // MARK: Cards
                catalogSection("Cards") {
                    VStack(spacing: AppSpacing.compact) {
                        // SpendingCard pair
                        HStack(spacing: AppSpacing.element) {
                            SpendingCard(title: "Spent",  amount: 355.13,  icon: "arrow.down.circle.fill", color: .red)
                            SpendingCard(title: "Income", amount: 4200.00, icon: "arrow.up.circle.fill",   color: .green)
                        }

                        // Balance card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Balance").font(.subheadline).fontWeight(.medium).foregroundColor(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("$355.13").font(AppTypography.prominentBalance)
                                Text("spent").font(.subheadline).foregroundColor(.secondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.secondaryCardBackground).frame(height: 8)
                                    Capsule().fill(Color.themeAccent)
                                        .frame(width: geo.size.width * 0.15, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .appCardStyle()
                    }
                }

                // MARK: Search Bar
                catalogSection("Search Bar") {
                    VStack(spacing: AppSpacing.compact) {
                        SearchBar(text: .constant(""), placeholder: "Search transactions...")
                        SearchBar(text: .constant("Netflix"), isLoading: false)
                        SearchBar(text: .constant("searching..."), isLoading: true)
                    }
                }

                // MARK: Transaction Rows
                catalogSection("Transaction Rows") {
                    VStack(spacing: AppSpacing.compact) {
                        ForEach(FC_MockData.transactions.prefix(4)) { tx in
                            let cat = FC_MockData.category(id: tx.categoryId)
                            FC_TransactionRowView(
                                categoryIcon:   cat.icon,
                                categoryColor:  cat.color,
                                categoryName:   cat.name,
                                note:           tx.note,
                                date:           tx.date,
                                amount:         tx.amount,
                                hasSplit:       tx.hasSplit,
                                originalAmount: nil,
                                currencyCode:   nil
                            )
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                        }
                    }
                }

                // MARK: Empty States
                catalogSection("Empty State") {
                    EmptyStateView(
                        icon: "tray.fill",
                        title: "No Transactions",
                        message: "Add your first transaction to get started.",
                        actionTitle: "Add Transaction",
                        action: {}
                    )
                    .appCardStyle()
                }

                // MARK: Headers (static, no scroll)
                catalogSection("Overlay Header — Root") {
                    ZStack(alignment: .top) {
                        Color.secondaryCardBackground
                            .frame(height: 70)
                            .cornerRadius(AppRadius.medium)
                        OverlayHeaderView(
                            mode: .root(
                                title: "Home",
                                trailing: AnyView(
                                    ProfileAvatar(text: "D", color: Color(hex: "#FF9500"), size: 34)
                                )
                            ),
                            scrollOffset: 0
                        )
                    }
                }

                catalogSection("Overlay Header — Navigation") {
                    ZStack(alignment: .top) {
                        Color.secondaryCardBackground
                            .frame(height: 70)
                            .cornerRadius(AppRadius.medium)
                        OverlayHeaderView(
                            mode: .navigation(title: "Account Settings", onBack: {}),
                            scrollOffset: 0
                        )
                    }
                }

                catalogSection("Modal Header") {
                    VStack(spacing: AppSpacing.compact) {
                        ModalHeader(title: "Add Transaction", currentStep: 2, totalSteps: 3, onBack: {}, onClose: {})
                        ModalHeader(title: "Select Currency", currentStep: nil, totalSteps: nil, onBack: nil, onClose: {})
                    }
                }

                catalogSection("Detail Header") {
                    DetailHeaderView(
                        title: "Food & Drink",
                        subtitle: "Today at 12:34 PM",
                        onBack: {},
                        backgroundColor: Color(hex: "#FF9500"),
                        textColor: .white,
                        height: 180,
                        avatar: {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundColor(.white)
                                )
                        },
                        actions: {
                            HStack(spacing: AppSpacing.compact) {
                                Button("Edit") {}
                                    .foregroundColor(.white).font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(Color.white.opacity(0.2)).clipShape(Capsule())
                            }
                        }
                    )
                    .cornerRadius(AppRadius.card)
                    .clipped()
                }

                Spacer().frame(height: AppSpacing.section)
            }
            .padding(.top, AppSpacing.section)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
    }

    // MARK: - Layout Helpers

    private func catalogHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.micro) {
            Text(title)
                .font(AppTypography.titleDisplay)
                .foregroundColor(.primary)
            Text("iOS 26 · System Theme · All components 1:1 with production")
                .font(AppTypography.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, AppSpacing.margin)
    }

    private func catalogSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(title)
                .font(AppTypography.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, AppSpacing.margin)

            content()
                .padding(.horizontal, AppSpacing.margin)
        }
    }
}
