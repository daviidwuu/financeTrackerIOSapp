# wym UI/UX Master Guide

**Version 1.0** | *The definitive visual manual for the wym Finance Tracker.*

---

## 1. Core Philosophy: "Premium Utility"

wym is not just a spreadsheet; it is a **financial companion**. Our design language, **"Premium Utility,"** balances the efficiency of a tool with the tactile joy of a physical object.

### The Three Pillars
1.  **Monochromatic Foundation**: The app structure is Black, White, and Gray. This neutrality allows the **user's data** (Category Colors) to shine without clashing.
2.  **Physical Depth**: We treat UI elements as physical cards. They have weight, rounded corners (`AppRadius`), and occupy space. They don't just "appear"; they slide, expand, and stick.
3.  **Tactile Feedback**: Every significant interaction (selection, deletion, success) must have a corresponding **Haptic Feedback** (`HapticManager`). The app should *feel* responsive.

---

## 2. Design System Tokens

All views must use these tokens found in `DesignSystem.swift`. **Hardcoded values are strictly prohibited.**

### A. Typography (`AppTypography`)
We use **SF Pro Rounded** for a friendly, modern numeric feel.

| Token | Size | Weight | Usage |
| :--- | :--- | :--- | :--- |
| `heroInput` | **64pt** | Bold | The massive input field in "Add Transaction". |
| `prominentBalance` | **42pt** | Bold | The main dashboard balance. |
| `titleDisplay` | **34pt** | Bold | Large page titles (e.g., "Welcome, David"). |
| `sectionHeader` | **28pt** | Bold | Headers for major sections (e.g., "Recent"). |
| `headline` | System | Semibold | Card titles, Button text. |
| `subheadline` | System | Regular | Metadata, dates, secondary info. |

### B. Spacing (`AppSpacing`)
Consistency in whitespace creates rhythm.

| Token | Value | Usage |
| :--- | :--- | :--- |
| `margin` | **20pt** | Global horizontal padding (Left/Right of screen). |
| `section` | **32pt** | Vertical gap between logical groups (e.g., Balance Card vs. List). |
| `element` | **16pt** | Gap between items inside a card or grid. |
| `compact` | **8pt** | Tight gap (e.g., Icon to Text). |

### C. Shapes & Radius (`AppRadius`)
Everything is rounded. Sharp corners are forbidden.

| Token | Value | Usage |
| :--- | :--- | :--- |
| `large` | **28pt** | Modal sheets, large container backgrounds. |
| `button` | **25pt** | "Capsule" buttons (Primary Actions). |
| `medium` | **16pt** | Standard Cards (Transaction rows, Budget items). |
| `small` | **12pt** | Inner badges, progress bars. |

### D. Colors (`AppColors`)
*   **Background**: `SystemBackground` (White/Black).
*   **Secondary Background**: `SecondarySystemBackground` (Light Gray/Dark Gray) for Cards.
*   **Brand**: `Blue` (Actions), `Green` (Income/Success), `Red` (Expense/Destructive).
*   **Palette**: 20+ custom hues for User Categories.

---

## 3. Global Components

These are the building blocks of wym. Reuse them.

### A. Detail Header (`DetailHeaderView`)
The standard header for any "Detail" screen (Transaction, Friend, Group).
*   **Visuals**: Full-width colored background (or Black) with a large centered Avatar.
*   **Behavior**: Pinned to the top.
*   **Content**: Title, Subtitle, and a bottom slot for Actions (e.g., "Edit").
*   **Implementation**: `FinanceTracker/Views/Components/DetailHeaderView.swift`

### B. Wizard Layout (`WizardLayout`)
The standard container for any multi-step form (Add Transaction, Add Budget).
*   **Visuals**: Progress bar in header, content transition animations (slide left/right).
*   **Behavior**: "Sticky" Action Bar at the bottom that stays visible above the keyboard.
*   **Implementation**: `FinanceTracker/Views/Components/WizardLayout.swift`

### C. Standard Card
The default container for lists and summaries.
*   **Style**: `SecondarySystemBackground` with `AppRadius.medium`.
*   **Shadow**: None by default (flat design). Use shadows only for floating elements.
*   **Interaction**: `ScaleEffect` (0.98) on press for tactile feel.

---

## 4. Interaction Patterns

### A. Sticky Action Bar
Primary actions (Save, Next, Pay) must never be hidden by scroll.
*   **Pattern**: Use `.safeAreaInset(edge: .bottom)` to pin buttons.
*   **Validation**: Disabled buttons should look visually distinct (lower opacity) but remain visible.

### B. Swipe Actions
*   **Leading (Blue)**: Edit / Modify.
*   **Trailing (Red)**: Delete / Destructive.
*   **Haptics**: `light` on swipe open, `medium` on edit tap, `heavy` on delete tap.

### C. Empty States
Never leave a screen blank.
*   **Visual**: Large SF Symbol (Gray, 60pt+).
*   **Text**: Friendly message ("No transactions yet").
*   **Action**: A clear button to resolve the empty state ("Add One").

---

## 5. Screen-Specific Guidelines

### A. Home (Dashboard)
*   **Hero**: "Balance Card" showing distinct "Spent" vs "Left" states.
*   **List**: `List` with hidden separators. Rows are individual cards with spacing.
*   **Animation**: Streak flame animates on appear.

### B. Wallet (Budgets)
*   **Visuals**: Heavy use of **Circular Progress Bars** and **Category Icons**.
*   **Logic**: "Infinite Scroll" feel. Sections (Savings, Recurring, Budgets) are clearly divided by `AppSpacing.section`.

### C. Social (Friends & Groups)
*   **Identity**:
    *   **Groups**: Gradient Backgrounds.
    *   **Friends**: Initials on computed color backgrounds.
*   **Headers**: Use `DetailHeaderView` exclusively.
*   **Lists**: "Contact Card" style—Avatar left, Name/Status middle, Action right.

### D. Profile
*   **Avatar**: Large (86pt) centered.
*   **Menu**: Standard iOS Form style but with `SecondarySystemBackground` cards.

---

## 6. Iconography Standards

*   **List Heroes**: **48x48pt** Circle container. Icon size ~20pt.
*   **Grid Items**: **32x32pt** Circle container.
*   **Detail Hero**: **80x80pt** Circle container. Icon size ~32pt.
*   **Style**: Always use SF Symbols `.fill` variants for weight.

---

*This guide is a living document. As new patterns emerge, update this file to maintain a single source of truth.*
