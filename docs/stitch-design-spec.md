# FinanceTracker Stitch 1:1 Design Spec

## Goal
Recreate the current FinanceTracker app design in Stitch as faithfully as possible, preserving layout structure, visual hierarchy, spacing rhythm, rounded geometry, and interaction tone from the existing SwiftUI implementation.

## Product Structure
- App shell uses a tab layout with `Home`, `Social`, `Wallet`, and a center `Add` action.
- Primary screens are wrapped in `NavigationStack`.
- Root screens use a sticky overlay header instead of the default iOS navigation bar.
- Main content is built from vertically scrolling plain lists on top of a themed background surface.

## Visual Direction
- Mood: soft, premium, calm, utility-first.
- Surfaces: layered neutral cards on top of a theme-aware background.
- Geometry: heavily rounded cards, pills, and circular icon treatments.
- Typography: standard iOS text styles with rounded, bold emphasis on hero numbers.
- Motion: small spring or ease transitions, numeric transitions for balances, subtle logo reveal, light haptic feedback on tap.

## Core Tokens

### Radius
- Large container radius: `28`
- Standard card radius: `20`
- Medium card radius: `16`
- Small card radius: `12`
- Extra small radius: `6`
- Button capsule treatment is used broadly for CTAs and search.

### Spacing
- Standard screen margin: `20`
- Large section spacing: `24`
- Standard in-card element spacing: `16`
- Compact row spacing: `8`
- Micro spacing: `4`

### Sizing
- List avatar/icon circle: `48x48`
- Medium avatar: `40x40`
- Small avatar: `32x32`
- Icon button: `44x44`

### Typography
- Display title: large bold title
- Section header: title bold
- Headline: semibold headline
- Subheadline: standard subheadline
- Balance hero: large rounded bold number
- Small metrics use rounded subheadline or caption styling

## Color System
- `backgroundPrimary`: theme-aware app background
- `cardBackground`: primary elevated surface
- `secondaryCardBackground`: secondary muted surface
- `textPrimary`: black in light mode, white in dark mode
- `themeAccent`: theme accent color
- Functional success: `#34C759`
- Functional error: `#FF3B30`
- Accent examples present across the app: blue, orange, green, red

## Global Components

### Overlay Header
- Root screens use a large title header pinned at the top.
- Header fades in a blurred background as content scrolls.
- Standard root style:
  - large title on top or welcome-style stacked greeting
  - optional subtitle beneath
  - optional trailing circular icon buttons
- Navigation style:
  - circular back button on the left
  - centered title
  - optional trailing action button

### Card Language
- Most content appears inside rounded cards with soft contrast from the background.
- Cards often include:
  - leading circular icon/avatar
  - text stack in the middle
  - trailing chevron, metric, or action
- Error or destructive cards add a subtle red outline.

### Controls
- Primary button:
  - full-width capsule
  - 50pt height
  - filled with dark text-primary or theme accent
- Secondary button:
  - full-width capsule
  - muted secondary surface fill
- Search:
  - 44pt capsule
  - left magnifying glass
  - optional trailing clear or loading state
- Add rows:
  - dashed circular plus icon
  - card-like row with clear empty-state energy

## Screen Spec

### Welcome
- Full-screen centered composition on `backgroundPrimary`.
- Top area:
  - white circular logo plate with shadow
  - `creditcard.fill` icon
  - animated logo scale/fade
- Middle:
  - wordmark `wym`
  - subtitle `Master your money with ease`
- Bottom:
  - primary `Get Started` capsule in white with black text
  - secondary `I already have an account` capsule on card surface
  - tertiary text button `See plans & pricing`

### Home
- Welcome-style overlay header:
  - small top text `Welcome`
  - large user name beneath
  - orange streak badge beside the name
  - trailing trophy and profile circular buttons
- First hero card is `Balance`:
  - label on top
  - large rounded amount
  - tap toggles between `spent` and `left`
  - pill progress bar beneath
- Optional stacked priority sections:
  - Friend Requests
  - Action Required for group deletion
  - Pending Requests
- Main section:
  - `Recent Transactions` title row with `View All`
  - transaction rows on individual rounded cards
  - leading/trailing swipe actions for edit/delete
  - optional native ad row before transactions
- Sheets are used for transaction detail, edit, add flow, profile, missions, and full transaction history.

### Social
- Overlay header:
  - title `Social`
  - subtitle `Split bills and track shared expenses`
- Top controls:
  - custom segmented control with `Groups`, `Friends`, `Leaderboard`
  - capsule search bar beneath
- Groups tab:
  - red outlined `Action Required` cards for group deletion decisions
  - invitation cards
  - dashed `Create New Group` row
  - standard group cards with swipe-to-delete for creators
- Friends tab:
  - pending request cards
  - dashed `Add Guest` row
  - friend cards and guest cards
- Leaderboard tab:
  - podium module for top 3 when unfiltered
  - leaderboard rows below
  - ad row near the bottom
- Sticky bottom ad banner floats above screen padding.

### Wallet
- Overlay header:
  - title `Wallet`
- First section is a tappable `Net Worth` card:
  - small label
  - large rounded amount
  - amount color flips to error color when negative
- Section order:
  - Saving Goals
  - Native ad
  - Calendar
  - Recurring
  - Budgets
- Saving goal rows:
  - colored circular icon
  - name
  - current versus target amount
  - target date meta row
  - trailing completion percentage
- Recurring rows:
  - reusable recurring transaction cards
- Budget rows:
  - colored circular icon
  - category label
  - trailing remaining or spent amount
- All collection rows use rounded cards and swipe actions for edit/delete.

## Interaction Tone
- Taps trigger light haptics.
- Confirm actions such as success states use stronger feedback.
- Destructive actions use swipe gestures and alert confirmation.
- Modal flows use sheets with medium/large detents where appropriate.
- Numeric and visibility changes animate with spring motion.

## Stitch Build Notes
- Keep the background and card colors theme-aware rather than hard-coding a single palette.
- Preserve the `20pt` horizontal margin rhythm across root screens.
- Prefer rounded geometry everywhere over sharp rectangles.
- Keep list backgrounds visually clear so cards float over the app background.
- Avoid default iOS grouped-list chrome; the design language is custom, cleaner, and more editorial.
- Maintain the top overlay header behavior as part of the shell, not per-card content.

## Source Mapping
- Home screen: `FinanceTracker/Views/Home/HomeView.swift`
- Social screen: `FinanceTracker/Views/Social/SocialDashboardView.swift`
- Wallet screen: `FinanceTracker/Views/Wallet/WalletView.swift`
- Welcome screen: `FinanceTracker/Views/Onboarding/WelcomeView.swift`
- Shared design tokens: `FinanceTracker/DesignSystem.swift`
- Shared color semantics: `FinanceTracker/Color+Extensions.swift`
- Shared header: `FinanceTracker/Views/Components/OverlayHeaderView.swift`
- Shared search: `FinanceTracker/Views/Components/SearchBar.swift`
- Shared buttons: `FinanceTracker/Views/Components/ButtonStyles.swift`
