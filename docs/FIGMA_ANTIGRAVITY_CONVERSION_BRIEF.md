# FinanceTracker to Figma Conversion Brief

Use this brief inside Antigravity with the configured `figma` MCP server to convert the current SwiftUI codebase into an editable Figma file.

## Goal

Create a new Figma file that turns this iOS app into a coherent design system plus product screen library.

The output should not be a flat screenshot dump. It should be a proper Figma working file with:

- a foundations page
- reusable components
- major app screens and flows
- clear page structure for future iteration

## Product Summary

FinanceTracker is an iOS SwiftUI finance app with three authenticated primary tabs plus onboarding.

Primary areas:

- `Home`: personal finance dashboard with balance, progress, requests, and recent transactions
- `Social`: groups, friends, leaderboard, shared-expense flows
- `Wallet`: net worth, savings goals, recurring transactions, budgets, and calendar insights
- `Onboarding`: welcome, account, profile, username, income, categories

## Source Files to Analyze First

Read these first before designing:

- `FinanceTracker/DesignSystem.swift`
- `docs/UI_UX_GUIDE.md`
- `FinanceTracker/FinanceTrackerApp.swift`
- `FinanceTracker/ContentView.swift`
- `FinanceTracker/Views/Home/HomeView.swift`
- `FinanceTracker/Views/Social/SocialDashboardView.swift`
- `FinanceTracker/Views/Wallet/WalletView.swift`
- `FinanceTracker/Views/Onboarding/WelcomeView.swift`
- `FinanceTracker/Views/Onboarding/OnboardingView.swift`
- `FinanceTracker/Views/Profile/ProfileView.swift`

Then inspect related component files as needed.

## Visual Direction

Follow the app's documented visual language: "Premium Utility".

Core traits:

- monochromatic foundation
- strong use of rounded cards and capsule controls
- tactile, iOS-native feel
- clean neutral base so data colors stand out
- friendly finance-product tone, not banking-corporate stiffness

## Foundations to Extract

Build a `Foundations` page in Figma with:

- color tokens
- typography scale
- spacing scale
- corner radius scale
- icon sizing rules
- state colors for income, expense, destructive, success, selection

Map these code tokens into Figma styles/variables:

- `AppRadius`
- `AppSpacing`
- `AppTypography`
- `AppColors`
- `AppSize`

## Required Pages in Figma

Create these pages:

1. `00 Foundations`
2. `01 Components`
3. `02 Onboarding`
4. `03 Main App`
5. `04 Social Flows`
6. `05 Wallet Flows`

## Components to Build

Create reusable components for at least:

- tab bar with `Home`, `Social`, `Wallet`, and center `Add`
- overlay/sticky page header
- balance card
- progress bar and circular progress treatments
- transaction row card
- empty state block
- segmented control
- search bar
- friend/group list cards
- request/action-required cards
- savings goal card
- recurring transaction row
- budget/category card
- primary capsule button
- icon avatar variants
- list section header

Use variants where the code implies states:

- selected vs unselected tabs
- spent vs left balance state
- groups vs friends segments
- positive vs negative financial states
- empty vs populated states where helpful

## Screens to Design

Design these screens at minimum:

- Welcome
- Onboarding flow overview
- Home dashboard
- Social dashboard
- Wallet overview
- Profile

Then add supporting screens or frames for:

- Add transaction
- All transactions
- Group detail
- Friend detail
- Saving goal detail or edit flow
- Recurring transaction detail
- Budget/category management
- Subscription/paywall

## Layout Guidance from Code

Important implementation details reflected in the code:

- The authenticated app uses a 3-tab structure with a center add action.
- `Home` uses a hero balance card, actionable inbox sections, and recent transactions.
- `Social` uses a sticky header, segmented control, search, and contact-card style rows.
- `Wallet` uses stacked sections for net worth, saving goals, calendar, recurring items, and budgets.
- Lists use card-like rows with hidden separators and generous spacing.
- Rounded geometry is part of the brand; avoid sharp corners.

## Quality Bar

The file should feel like a real product design source file:

- reusable components instead of duplicated frames
- variables/styles where possible
- consistent spacing and naming
- screen layouts that are ready for iteration
- preserve iOS conventions unless the code clearly does something custom

## Workflow

Follow this order:

1. Analyze the code and docs
2. Create a new Figma file
3. Build foundations
4. Build reusable components
5. Assemble major screens from those components
6. Add secondary screens only after core areas are stable

## Constraints

- Keep this faithful to the current codebase, not a speculative redesign
- Improve organization and consistency, but do not invent an unrelated aesthetic
- Prefer SF-symbol-like placeholders and iOS-native patterns when code implies them
- Preserve the monochrome-plus-data-color strategy from the UI guide

## Deliverable

At the end, provide:

- the created Figma file link
- a short summary of pages/components created
- any screens that still need manual follow-up
