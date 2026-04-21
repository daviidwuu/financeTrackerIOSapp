# FinanceTracker Design Specification

Use these exact values to ensure 100% accuracy when recreating designs in Figma.

## 🎨 Colors (Hex Codes)

### Semantic Colors
| Name | Light Mode | Dark Mode |
| :--- | :--- | :--- |
| `backgroundPrimary` | #FFFFFF | #000000 |
| `cardBackground` | #F2F2F7 | #1C1C1E |
| `secondaryCardBackground` | #E5E5EA | #2C2C2E |
| `themeAccent` | #007AFF | #0A84FF |
| `functionalSuccess` | #34C759 | #30D158 |
| `functionalError` | #FF3B30 | #FF453A |

### Dynamic System Colors (UIKit Aliases)
- `secondaryLabel`: 60% opacity of `textPrimary`
- `tertiaryLabel`: 30% opacity of `textPrimary`

---

## 📏 Spacing & Radius (Pixels)

### AppSpacing
- `margin`: 20px (Standard horizontal margin)
- `section`: 32px (Between major sections)
- `element`: 16px (Between elements in a section)
- `compact`: 8px (Tight groupings)
- `micro`: 4px (Badges/Small insets)

### AppRadius
- `large`: 28px
- `card`: 20px
- `medium`: 16px
- `small`: 12px
- `button`: 25px (Capsule style)

---

## 🔤 Typography (San Francisco / SF Pro)

| Style | Font Size | Weight | Design |
| :--- | :--- | :--- | :--- |
| `titleDisplay` | 34pt | Bold | Default |
| `prominentBalance`| 34pt | Bold | Rounded |
| `sectionHeader` | 28pt | Bold | Default |
| `headline` | 17pt | Semibold | Default |
| `body` | 17pt | Regular | Default |
| `caption` | 12pt | Regular | Default |
| `heroInput` | 64pt | Bold | Rounded |

---

## 🧱 Core UI Blocks

### Cards (`appCardStyle`)
- **Padding**: 16px (All sides, `AppSpacing.element`).
- **Radius**: 16px by default (`AppRadius.medium`), or 20px (`card`), 28px (`large`).
- **Background**: `cardBackground`.

### Shadows & Depth
- **Elevated Buttons/Floaters**: Drop Shadow (`Color #000000` at 10% opacity, Y: 4, Blur: 10).
- **Hero/Welcome Elements**: Drop Shadow (`Color #FFFFFF` at 30% opacity, Y: 10, Blur: 20) for dark mode / prominent light mode elements.

### Navigation & Tab Bars
- **iOS Standard Nav Bar**: Large Titles enabled by default, collapses to Inline on scroll.
- **Bottom Tab Bar**: 4 slots. Unselected icon color is `secondaryLabel`, selected is `textPrimary`. 

---

## 🏆 Specialized Components

### Gamification (Leaderboard)
- **Podium Ranks**:
    - **Rank 1**: Gold (#FFD700), 1.2x Scale, Circle Stroke (3px), Crown Icon.
    - **Rank 2**: Silver (#C0C0C0), 0.9x Scale, Circle Stroke (3px).
    - **Rank 3**: Bronze (#CD7F32), 0.9x Scale, Circle Stroke (3px).
- **Points Pill**: Background `tertiarySystemFill`, Radius `Capsule`, Horizontal Padding 10px, Vertical Padding 6px.
- **Rank Badge**: Circle (24x24px) overlapping avatar at bottom-center.

### Social & Splitting
- **Debt Instruction Row**: Horizontal layout, 8px spacing (`compact`), 12px radius (`small`), centered `arrow.right`.
- **Pending Split Card**: 
    - **Stroke**: 1px colored border matching the status color.
    - **Badges**: Guest/Status labels with 8px horizontal padding, 4px vertical, opacity background (12%).
    - **Actions**: Dynamic set of 44x44px circular buttons with `compactIconName`.

---

## ⚡ Interaction & Stateful UI

To prevent mismatches, these states **must** be designed in Figma before implementation:

### 🔘 Button States
- **Scale Effect**: All buttons use a `.scaleEffect` on tap.
    - **Primary/Secondary**: 0.98 scale
    - **Small**: 0.96 scale
- **Loading State**: Buttons should have a `ProgressView` (spinner) variant.
- **Disabled State**: Opacity reduced, background color shifts to `secondaryCardBackground`.

---

## 📂 Category Asset Library

| Category | Primary Icon | Hex Color |
| :--- | :--- | :--- |
| **Food & Drink** | `fork.knife` | #FF9500 |
| **Transport** | `car.fill` | #007AFF |
| **Shopping** | `bag.fill` | #AF52DE |
| **Health** | `heart.fill` | #FF2D55 |
| **Home** | `house.fill` | #34C759 |
| **Entertainment** | `tv.fill` | #5856D6 |
| **Income** | `dollarsign.circle.fill` | #34C759 |
