// MARK: - FC_DesignTokens.swift
// Frontend layer — design token reference for Figma.
//
// This file documents every token used throughout the app.
// It does NOT redefine any token — it re-exports them with
// Figma-friendly names and inline documentation.
//
// HOW TO USE IN FIGMA:
//   1. Open the Figma iOS plugin (e.g. "Figma to SwiftUI" or "Locofy").
//   2. Point it at this file + the Components/ and Screens/ folders.
//   3. The plugin reads the token names below to match Figma styles.
//
// TOKEN NAMING CONVENTION:
//   FC/<group>/<token>   (mirrors Figma's grouping slash syntax)

import SwiftUI

// MARK: - Radius Tokens
// Figma: Corner Radius styles
// Usage: Always use these instead of hardcoded CGFloat values.
//
// FC/Radius/Large       → 28  — onboarding cards, full-screen modals
// FC/Radius/Card        → 20  — large card containers
// FC/Radius/Medium      → 16  — standard cards, list rows
// FC/Radius/Small       → 12  — chips, tags
// FC/Radius/Button      → 25  — Capsule approximation for fixed-size buttons
// FC/Radius/Badge       → 4   — status badges
// FC/Radius/XSmall      → 6   — tiny pills
// FC/Radius/RowVertical → 14  — settings row vertical padding (not a radius)

// MARK: - Spacing Tokens
// Figma: Spacing / Gap styles
// Usage: Horizontal margins, section gaps, element gaps.
//
// FC/Spacing/Margin   → 20  — horizontal screen margin (left/right padding)
// FC/Spacing/Section  → 32  — gap between major content sections
// FC/Spacing/Large    → 24  — wizard / onboarding container padding
// FC/Spacing/Element  → 16  — gap between elements within a section
// FC/Spacing/Compact  → 8   — tight groupings, list row bottom padding
// FC/Spacing/Micro    → 4   — badges, tiny insets

// MARK: - Size Tokens
// Figma: Component / Layer sizes
//
// FC/Size/AvatarList   → 48  — list-row avatar circles
// FC/Size/AvatarMedium → 40  — medium avatar (social cards)
// FC/Size/AvatarHero   → 86  — profile hero avatar
// FC/Size/AvatarSmall  → 32  — small avatars (accept/decline buttons)
// FC/Size/IconButton   → 44  — minimum tap target for icon buttons
// FC/Size/HeaderHeight → 300 — full detail header height
// FC/Size/HeaderSlim   → 80  — slim navigation header height
// FC/Size/ButtonHeight → 50  — primary/secondary full-width button height

// MARK: - Typography Tokens
// Figma: Text styles
// All use SF Pro (system font) with Dynamic Type support.
//
// FC/Type/HeroInput          → system 64pt bold rounded   — amount entry
// FC/Type/ProminentBalance   → .largeTitle bold rounded   — main balance on Home
// FC/Type/TitleDisplay       → .largeTitle bold           — screen titles
// FC/Type/SectionHeader      → .title bold                — section headings
// FC/Type/Headline           → .headline semibold         — card headings
// FC/Type/Subheadline        → .subheadline               — secondary text
// FC/Type/Body               → .body                      — primary body text
// FC/Type/Caption            → .caption                   — metadata / dates

// MARK: - Color Tokens
// Figma: Color styles
// All colors are theme-adaptive (light/dark + 6 premium themes).
// The values below represent the DEFAULT system theme.

struct FC_DesignTokens {

    // MARK: Background
    /// FC/Color/BackgroundPrimary
    /// Light: #FFFFFF · Dark: #000000
    /// Used for: every screen background, modal backgrounds, wizard backgrounds.
    static let backgroundPrimary = Color.backgroundPrimary

    /// FC/Color/CardBackground
    /// Light: UIColor(white:0.97) · Dark: UIColor(white:0.10)
    /// Used for: every card, list row cell background, settings menu sections.
    static let cardBackground = Color.cardBackground

    /// FC/Color/SecondaryCardBackground
    /// Light: UIColor(white:0.94) · Dark: UIColor(white:0.15)
    /// Used for: secondary button fill, search bar background, tag chips.
    static let secondaryCardBackground = Color.secondaryCardBackground

    /// FC/Color/ListBackground
    /// Light: systemGroupedBackground · Dark: #000000
    /// Used for: List / Form backgrounds.
    static let listBackground = Color.listBackground

    // MARK: Text
    /// FC/Color/TextPrimary
    /// Light: #000000 · Dark: #FFFFFF
    /// Used for: primary button fill (system theme), primary text override.
    static let textPrimary = Color.textPrimary

    // MARK: Accent
    /// FC/Color/ThemeAccent
    /// Light: system blue (#007AFF) · Dark: system blue (#007AFF)
    /// Used for: active toggles, checkmarks, primary CTA (non-system themes), links.
    static let themeAccent = Color.themeAccent

    // MARK: Functional
    /// FC/Color/FunctionalSuccess   → #34C759 (iOS System Green)
    static let functionalSuccess = Color.functionalSuccess

    /// FC/Color/FunctionalError     → #FF3B30 (iOS System Red)
    static let functionalError = Color.functionalError

    /// FC/Color/FunctionalIncome    → system green (positive transactions)
    static let functionalIncome = AppColors.functionalIncome

    /// FC/Color/FunctionalExpense   → system red (negative transactions)
    static let functionalExpense = AppColors.functionalExpense

    // MARK: Premium Badge Colors
    /// FC/Color/BadgeKing    → #F5A623 (gold)
    static let badgeKing = Color(hex: "#F5A623")

    /// FC/Color/BadgePro     → system blue
    static let badgePro = Color.blue

    /// FC/Color/BadgeSaver   → system green
    static let badgeSaver = Color.green

    // MARK: Category Palette (26 colors, all used for category dots/icons)
    // These are the exact colors from AppConstants.allColors
    static let categoryPalette: [(name: String, hex: String)] = [
        ("System Red",        "#FF3B30"),
        ("System Pink",       "#FF2D55"),
        ("Deep Pink",         "#E0245E"),
        ("Deep Red",          "#D0021B"),
        ("System Orange",     "#FF9500"),
        ("Dark Orange",       "#FF7F00"),
        ("Gold",              "#F5A623"),
        ("System Yellow",     "#FFCC00"),
        ("Bright Yellow",     "#FFD60A"),
        ("System Green",      "#34C759"),
        ("Bright Green",      "#28CD41"),
        ("Light Green",       "#4CD964"),
        ("Teal",              "#00C7BE"),
        ("Light Blue",        "#5AC8FA"),
        ("System Blue",       "#007AFF"),
        ("Twitter Blue",      "#1DA1F2"),
        ("Dark Blue",         "#0040DD"),
        ("System Indigo",     "#5856D6"),
        ("System Purple",     "#AF52DE"),
        ("Vivid Purple",      "#794BC4"),
        ("Black",             "#000000"),
        ("Dark Gray",         "#3A3A3C"),
        ("System Gray",       "#8E8E93"),
        ("Light Gray",        "#C7C7CC"),
        ("Very Light Gray",   "#E5E5EA"),
        ("White",             "#FFFFFF"),
    ]

    // MARK: Selection Palette (8 colors, used for group creation picker)
    static let selectionPalette: [String] = AppColors.selectionPalette

    // MARK: Premium Gradients
    // Used for group avatars, premium UI elements.
    //
    // FC/Gradient/Ocean    → blue → cyan
    // FC/Gradient/Sunset   → orange → pink
    // FC/Gradient/Berry    → purple → pink
    // FC/Gradient/Forest   → green → mint
    // FC/Gradient/Midnight → indigo → purple
    // FC/Gradient/Ember    → red → orange
    // FC/Gradient/Royal    → #4158D0 → #C850C0

    // MARK: App Theme Backgrounds (all 6 themes, both modes)
    // System theme is the default; premium themes are unlocked via subscription.
    //
    // Theme       Light BG     Dark BG      Accent Light  Accent Dark
    // .system     #FFFFFF      #000000      system blue   system blue
    // .pink       #FFEDF4      #1A000A      #FF4081       #FF80AB
    // .ocean      #E0F7FA      #00101A      #0288D1       #29B6F6
    // .midnight   #E8EAF6      #050714      #3F51B5       #7986CB
    // .forest     #E8F5E9      #001409      #388E3C       #66BB6A
    // .sunset     #FFF3E0      #1A0A00      #F57C00       #FFB74D
}

// MARK: - Figma Export Helper (JSON comment)
// Paste the string below into the Figma Token Studio plugin as a JSON token set.
// It encodes the system-theme (default) token values only.

/*
{
  "radius": {
    "large":       { "value": "28",  "type": "borderRadius" },
    "card":        { "value": "20",  "type": "borderRadius" },
    "medium":      { "value": "16",  "type": "borderRadius" },
    "small":       { "value": "12",  "type": "borderRadius" },
    "button":      { "value": "25",  "type": "borderRadius" },
    "badge":       { "value": "4",   "type": "borderRadius" },
    "xSmall":      { "value": "6",   "type": "borderRadius" }
  },
  "spacing": {
    "margin":   { "value": "20", "type": "spacing" },
    "section":  { "value": "32", "type": "spacing" },
    "large":    { "value": "24", "type": "spacing" },
    "element":  { "value": "16", "type": "spacing" },
    "compact":  { "value": "8",  "type": "spacing" },
    "micro":    { "value": "4",  "type": "spacing" }
  },
  "size": {
    "avatarList":   { "value": "48",  "type": "sizing" },
    "avatarMedium": { "value": "40",  "type": "sizing" },
    "avatarHero":   { "value": "86",  "type": "sizing" },
    "avatarSmall":  { "value": "32",  "type": "sizing" },
    "iconButton":   { "value": "44",  "type": "sizing" },
    "buttonHeight": { "value": "50",  "type": "sizing" }
  },
  "color": {
    "backgroundPrimary":      { "value": "#FFFFFF", "type": "color", "description": "Dark: #000000" },
    "cardBackground":         { "value": "#F7F7F7", "type": "color", "description": "Dark: #1A1A1A" },
    "secondaryCardBackground":{ "value": "#F0F0F0", "type": "color", "description": "Dark: #262626" },
    "textPrimary":            { "value": "#000000", "type": "color", "description": "Dark: #FFFFFF" },
    "themeAccent":            { "value": "#007AFF", "type": "color" },
    "functionalSuccess":      { "value": "#34C759", "type": "color" },
    "functionalError":        { "value": "#FF3B30", "type": "color" },
    "badgeKing":              { "value": "#F5A623", "type": "color" },
    "badgePro":               { "value": "#007AFF", "type": "color" },
    "badgeSaver":             { "value": "#34C759", "type": "color" }
  }
}
*/

// MARK: - Token Catalog Preview

#Preview("Design Token Catalog") {
    ScrollView {
        VStack(alignment: .leading, spacing: AppSpacing.section) {

            // MARK: Colors
            Group {
                Text("Background Colors")
                    .font(AppTypography.sectionHeader)
                    .padding(.horizontal, AppSpacing.margin)

                HStack(spacing: AppSpacing.element) {
                    tokenSwatch("backgroundPrimary", color: Color.backgroundPrimary)
                    tokenSwatch("cardBackground",    color: Color.cardBackground)
                    tokenSwatch("secondaryCard",     color: Color.secondaryCardBackground)
                }
                .padding(.horizontal, AppSpacing.margin)
            }

            Group {
                Text("Functional Colors")
                    .font(AppTypography.sectionHeader)
                    .padding(.horizontal, AppSpacing.margin)

                HStack(spacing: AppSpacing.element) {
                    tokenSwatch("themeAccent",    color: Color.themeAccent)
                    tokenSwatch("success",        color: Color.functionalSuccess)
                    tokenSwatch("error",          color: Color.functionalError)
                }
                .padding(.horizontal, AppSpacing.margin)
            }

            Group {
                Text("Premium Badge Colors")
                    .font(AppTypography.sectionHeader)
                    .padding(.horizontal, AppSpacing.margin)

                HStack(spacing: AppSpacing.element) {
                    tokenSwatch("king",  color: Color(hex: "#F5A623"))
                    tokenSwatch("pro",   color: .blue)
                    tokenSwatch("saver", color: .green)
                }
                .padding(.horizontal, AppSpacing.margin)
            }

            Group {
                Text("Category Palette")
                    .font(AppTypography.sectionHeader)
                    .padding(.horizontal, AppSpacing.margin)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.compact), count: 6),
                          spacing: AppSpacing.compact) {
                    ForEach(AppConstants.allColors.indices, id: \.self) { i in
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(AppConstants.allColors[i])
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
            }

            // MARK: Radius
            Group {
                Text("Corner Radius")
                    .font(AppTypography.sectionHeader)
                    .padding(.horizontal, AppSpacing.margin)

                VStack(spacing: AppSpacing.compact) {
                    ForEach([
                        ("large (28)",   AppRadius.large),
                        ("card (20)",    AppRadius.card),
                        ("medium (16)",  AppRadius.medium),
                        ("small (12)",   AppRadius.small),
                        ("button (25)",  AppRadius.button),
                        ("badge (4)",    AppRadius.badge),
                        ("xSmall (6)",   AppRadius.xSmall),
                    ], id: \.0) { label, radius in
                        HStack {
                            RoundedRectangle(cornerRadius: radius)
                                .stroke(Color.themeAccent, lineWidth: 1.5)
                                .frame(width: 60, height: 32)
                            Text(label).font(AppTypography.caption).foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.margin)
                    }
                }
            }

            // MARK: Typography
            Group {
                Text("Typography")
                    .font(AppTypography.sectionHeader)
                    .padding(.horizontal, AppSpacing.margin)

                VStack(alignment: .leading, spacing: AppSpacing.element) {
                    Text("HeroInput — 64pt Bold Rounded")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("ProminentBalance — LargeTitle Bold Rounded").font(AppTypography.prominentBalance).minimumScaleFactor(0.5).lineLimit(1)
                    Text("TitleDisplay — LargeTitle Bold").font(AppTypography.titleDisplay)
                    Text("SectionHeader — Title Bold").font(AppTypography.sectionHeader)
                    Text("Headline — Headline Semibold").font(AppTypography.headline)
                    Text("Subheadline — Subheadline").font(AppTypography.subheadline)
                    Text("Body — Body").font(AppTypography.body)
                    Text("Caption — Caption").font(AppTypography.caption)
                }
                .padding(.horizontal, AppSpacing.margin)
            }
        }
        .padding(.top, AppSpacing.section)
        .padding(.bottom, AppSpacing.section)
    }
    .background(Color.backgroundPrimary.ignoresSafeArea())
}

// Helper for the preview only
private func tokenSwatch(_ name: String, color: Color) -> some View {
    VStack(spacing: AppSpacing.micro) {
        RoundedRectangle(cornerRadius: AppRadius.small)
            .fill(color)
            .frame(height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        Text(name)
            .font(.system(size: 9))
            .foregroundColor(.secondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
    }
}
