# Design Guidelines & UI/UX Standards

This document establishes the visual consistency standards for the wym app. Adhere to these guidelines when creating new views or refactoring existing ones.


## 1. UX Philosophy: User-First & Intuitive

**The Golden Rule**: Design for the human, not the system. Every interaction should feel effortless, friendly, and obvious.

*   **User-First**: Prioritize what the user wants to *achieve* (e.g., "Split a Bill") over the technical steps (e.g., "Create Transaction > Add Split > Select User").
*   **Friendly Tone**: Use approachable, conversational language.
    *   *Bad*: "Operation Successful."
    *   *Good*: "You're all set!" or "Transaction added."
*   **Intuitive Patterns**: Stick to standard iOS gestures and flows. If a user has to "learn" how to use a basic feature, we have failed.
    *   *Example*: Use swipe-to-delete, standard navigation stacks, and clear, labeled buttons.

## 2. Iconography & Element Sizes

| Component Context | Icon Size (pt) | Container Frame (pt) | Corner Radius | Example Views |
| :--- | :--- | :--- | :--- | :--- |
| **List Heroes** | N/A | **48 x 48** | Circle | `HomeView` (Transactions), `WalletView` (Budgets/Goals) |
| **Grid Selectors** | 14 (Font) | **32 x 32** | Circle | `AddTransactionView` (Category Grid) |
| **Menu / Settings** | 16 (Font) | **24 x 24** | N/A | `ProfileView` (Menu Rows) |
| **Detail Options** | 20 (Font) | **24 x 24** | N/A | `TransactionDetailView` (Rows) |
| **Profile Avatar** | 36 (Font) | **86 x 86** | Circle | `ProfileView` |

### Rules:
*   **List Items**: Always use **48x48** for the primary leading icon in a `List` or `ScrollView` row.
*   **Grids**: Use **32x32** for selectable grid items where space is at a premium.
*   **Menus**: Use smaller **24x24** frames for settings/utility rows to avoid overwhelming the text.
*   **Social & Profile**:
    *   **Groups**: Gradient Background + White SF Symbol.
    *   **Friends**: Random Color Background (seeded by name) + White Initials.
    *   **Guests**: Orange Tint Background + Icon.

## 3. Spacing & Layout

Use `DesignSystem.swift` constants instead of hardcoded values.

| Constant | Value (pt) | Use Case |
| :--- | :--- | :--- |
| `AppSpacing.margin` | **20** | Standard horizontal padding for the main view container. |
| `AppSpacing.section` | **32** | Vertical spacing between major view sections. |
| `AppSpacing.element` | **16** | Spacing between elements inside a card or group. |
| `AppSpacing.compact` | **8** | Tight spacing (e.g., between Text and Subtext). |

### Common Layout Patterns:
*   **List Row Insets**: `EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin)`
    *   *Why*: Ensures list content aligns perfectly with non-list headers.

## 4. Corner Radii

| Constant | Value (pt) | Use Case |
| :--- | :--- | :--- |
| `AppRadius.large` | **28** | Modal sheets, Large containers. |
| `AppRadius.button` | **25** | Action buttons (Capsule-like). |
| `AppRadius.medium` | **16** | Standard cards (Transactions, Budgets). |
| `AppRadius.small` | **12** | Inner elements, localized badges. |

## 5. Typography (Hero)

| Constant | Size (pt) | Use Case |
| :--- | :--- | :--- |
| `AppTypography.heroInput` | **64** | Main input fields (e.g., entering transaction amount). |
| `AppTypography.prominentBalance` | **42** | Dashboard balance display. |
| `AppTypography.titleDisplay` | **34** | User greetings, top-level titles. |
| `AppTypography.sectionHeader` | **28** | Section headings. |

## 6. Colors & Haptics

**Philosophy: Monochromatic Core + Functional Color**
The app relies on a clean, monochromatic foundation (Black/White/Gray) to feel premium and avoid visual clutter. Vibrant colors are reserved **strictly** for:
1.  **Categories**: To distinguish spending types instantly.
2.  **Positive/Negative Flow**: Green for Income, Red for distinct warnings.
3.  **Haptic Feedback**: Meaningful tactile response matched with visual cues.

*   **Primary Elements**: `.primary` (Monochrome).
*   **Secondary Metadata**: `.secondary` (Gray).
*   **Functional Highlights**:
    *   **Income**: `Color(hex: "#34C759")` (or Category Color).
    *   **Split Details**: Green text for reimbursed amounts.
    *   **Selected State**: Category Color background or heavy stroke.

**Haptic Rules**:
*   `light`: Navigation, toggles, generic taps.
*   `medium`: Confirming a selection, opening a menu.
*   `heavy`: Deleting items, destructive actions.
*   `success`: Completing a transaction, accepting an invite.
*   `error`: Failed operations, validation errors.

## 7. Component Standards

### Cards
*   **Background**: `Color(UIColor.secondarySystemBackground)` (Adapts to Dark Mode).
*   **Shadows**: Generally avoid on standard list items; use flat backgrounds with distinct colors. Use subtle shadows (`radius: 8, y: 4`) only for floating elements or highly prominent headers.

### Headers
*   **Structure**: `VStack(spacing: 4)` for Title + Subtitle.
*   **Navigation**: Use standard `NavigationStack` titles where possible, or `ProfileHeaderView` style for custom top-level dashboards.

## 8. Social & Detail View Patterns

### Premium Detail Headers
*   **Background**: Use `Color.black` (or extremely dark gray) for the header background in Detail views (`GroupDetailView`, `FriendDetailView`).
*   **Navigation**: Use **Floating Buttons** (Back, Settings) with a glassmorphism background (`.ultraThinMaterial` + Circle) to allow content to scroll underneath while maintaining reachability.
*   **Hero Content**:
    *   Large, centered avatars/icons with outer glows/shadows.
    *   White text for names/titles on the dark background.
    *   **Action Bar**: Floating action buttons (e.g., "Settle Up") anchored at the bottom of the header.

### Selection Cards (Wizards)
*   **Style**: Use **Horizontal Scrolling Cards** for picking items (e.g., Payers/Receivers) instead of standard lists.
*   **Selection State**:
    *   **Selected**: High contrast border (Brand Color) + Background Highlight.
    *   **Unselected**: Neutral background + grayscale content.
*   **Flow**: Use visual connectors (e.g., "Avatar -> Arrow -> Avatar") to explain complex relationships like debt settlement.
