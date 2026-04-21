# FinanceTracker Onboarding Figma Conversion Spec

This document translates the SwiftUI onboarding experience into a Figma-ready screen and component spec.

It is intentionally source-faithful. The goal is to recreate the current onboarding UX 1:1, not redesign it.

## Scope

Included flows:

- `Welcome`
- `Login`
- `Plans & Pricing`
- `Onboarding` six-step wizard
- `Edit Category` four-step sheet
- `Post-Onboarding Guide` four-step flow

Primary source files:

- `FinanceTracker/DesignSystem.swift`
- `FinanceTracker/Color+Extensions.swift`
- `docs/UI_UX_GUIDE.md`
- `FinanceTracker/Views/Onboarding/WelcomeView.swift`
- `FinanceTracker/Views/Onboarding/LoginView.swift`
- `FinanceTracker/Views/Onboarding/OnboardingView.swift`
- `FinanceTracker/Views/Onboarding/Steps/*.swift`
- `FinanceTracker/Views/Onboarding/PostOnboardingGuideView.swift`
- `FinanceTracker/Views/Profile/SubscriptionView.swift`

## Figma Page Structure

Create or update these pages first:

1. `00 Foundations`
2. `01 Components`
3. `02 Onboarding`

Suggested frame grouping inside `02 Onboarding`:

- `Entry`
- `Wizard`
- `Category Sheet`
- `Post Guide`

## Foundations To Mirror

### Typography

- `AppTypography.heroInput`: 64pt, bold, rounded. Used for name, username, income, category name, budget limit.
- `AppTypography.heroRounded(32)`: large celebratory guide titles.
- `AppTypography.heroRounded(28)`: primary onboarding step titles.
- `AppTypography.titleDisplay`: welcome brand title.
- `AppTypography.headline`: primary actions, card titles, plan titles.
- `AppTypography.subheadline`: secondary descriptions and metadata.
- `AppTypography.body`: explanatory copy.
- `AppTypography.caption`: validation, helper, and legal copy.

### Spacing

- `margin`: 20
- `section`: 32
- `large`: 24
- `element`: 16
- `compact`: 8
- `micro`: 4

### Radius

- `large`: 28
- `card`: 20
- `medium`: 16
- `small`: 12
- `button`: 25

### Core Colors

System theme:

- `backgroundPrimary`: white in light mode, black in dark mode
- `textPrimary`: black in light mode, white in dark mode
- `cardBackground`: very light gray in light mode, near-black gray in dark mode
- `secondaryCardBackground`: medium surface gray
- `themeAccent`: theme accent, default blue in system theme

Functional colors:

- `brandPrimary`: blue
- `functionalIncome`: green
- `functionalExpense`: red
- category palette includes orange, blue, red, purple, indigo, yellow, cyan

## Shared Components To Build In Figma

Create these reusable components before assembling screens:

- `Progress / Wizard Step Bar`
- `Button / Primary Capsule / Default`
- `Button / Primary Capsule / Disabled`
- `Button / Secondary Surface Capsule`
- `Button / Circle Back`
- `Input / Icon Text Field`
- `Input / Icon Secure Field`
- `Icon Hero / Concentric Circles`
- `List Row / Category`
- `Overlay / Swipe Guide`
- `Card / Widget`
- `Row / Numbered Instruction`
- `Sheet Header / Step`
- `Pricing Card / Selected`
- `Pricing Card / Unselected`

## Navigation Map

Entry branching:

- `Welcome` -> `Get Started` -> `Onboarding Step 1`
- `Welcome` -> `I already have an account` -> `Login`
- `Welcome` -> `See plans & pricing` -> `Plans & Pricing`

Wizard progression:

- Step 1 `Intro`
- Step 2 `Profile`
- Step 3 `Username`
- Step 4 `Income`
- Step 5 `Categories`
- Step 6 `Account`

Completion:

- successful account creation -> main app
- first authenticated appearance -> `Post-Onboarding Guide`

## Screen Specs

### Welcome

Structure:

- full-screen `backgroundPrimary`
- centered logo cluster with white 120x120 circle and `creditcard.fill`
- brand wordmark `wym`
- subtitle `Master your money with ease`
- bottom action stack

Actions:

- `Get Started`: white capsule, black text, white glow shadow
- `I already have an account`: `cardBackground` capsule
- `See plans & pricing`: plain text row with chevron

Motion:

- logo and content fade/slide in on appear

### Login

Structure:

- centered header: `Welcome Back`, `Sign in to continue`
- form with email and password fields
- right-aligned `Forgot Password?`
- optional inline error row with warning icon
- bottom sticky primary button `Log In`

Components:

- icon field rows use 24pt leading icon, padded `cardBackground`, radius `medium`

### Plans & Pricing

Structure:

- branded premium hero chip `king` in gold
- feature list
- selectable annual/monthly pricing cards
- fixed bottom CTA and legal block

States:

- selected pricing card flips to dark fill with gold outline and soft gold shadow
- unavailable state shows progress or fallback copy

### Onboarding Step 1: Intro

Structure:

- top progress bar `1/6`
- centered hero icon with two blue translucent circles
- title `Welcome to wym`
- supporting copy
- inline login link
- sticky bottom primary button `Continue`

Behavior:

- production view requests location and notification permission on appear

### Onboarding Step 2: Profile

Structure:

- progress bar `2/6`
- title `What should we call you?`
- subtitle
- oversized centered name field using `heroInput`
- sticky bottom back + continue controls

### Onboarding Step 3: Username

Structure:

- progress bar `3/6`
- title `Pick a Username`
- subtitle
- oversized centered username field
- availability state row underneath when text is present

Validation states to model:

- checking: spinner + caption
- available: green check + `Available`
- unavailable: red x + `Taken`
- invalid: `Too short` or `Required`

### Onboarding Step 4: Income

Structure:

- progress bar `4/6`
- green concentric hero icon
- title `What is your monthly income?`
- currency row with `$` and large numeric input
- helper caption

### Onboarding Step 5: Categories

Structure:

- progress bar `5/6`
- title and instructional copy
- list of rounded category cards
- each row: circular icon badge, category name, trailing budget text
- bottom `Add Category` action

Default seeded rows:

- Food & Drink
- Transport
- Bills
- Shopping
- Entertainment

Interaction states to prototype:

- tap row -> open `Edit Category` sheet
- swipe right -> reveal blue `Edit`
- swipe left -> reveal red `Delete`
- first appearance shows swipe-guide overlay

### Edit Category Sheet

This is a four-step modal flow with drag handle, overlay header, and a sticky CTA.

Steps:

1. `Category Name`
2. `Budget Limit`
3. `Select Icon`
4. `Select Color`

Header behavior:

- title `Step X of 4`
- back chevron on steps 2-4
- close icon on step 1
- trash action visible on step 1

### Onboarding Step 6: Account

Structure:

- progress bar `6/6`
- title `Create your account`
- subtitle about secure storage
- email and password fields
- optional red inline error copy
- sticky primary CTA changes label to `Create Account`

### Post-Onboarding Guide Step 1

- celebratory green check hero
- title `All Set!`
- explanation copy
- progress `1/4`
- `Next` CTA
- `Skip` button top-right

### Post-Onboarding Guide Step 2

- blue tap icon
- title `Quick Logging with Back Tap`
- four numbered instruction rows

### Post-Onboarding Guide Step 3

- purple widgets icon
- title `Stay On Top with Widgets`
- three widget cards
- additional numbered how-to section

### Post-Onboarding Guide Step 4

- yellow sparkles hero
- title `You're All Set!`
- final encouragement copy
- CTA label becomes `Get Started`

## Prototype Wiring Notes

In Figma prototype mode, wire these transitions:

- welcome entry buttons to onboarding, login, and pricing
- onboarding `Continue` and back arrows between all six steps
- category row tap to category sheet
- post-guide `Next`, `Back`, `Skip`, and final `Get Started`

Use overlays or annotations for behaviors that are runtime-only:

- permission prompts on intro
- username availability network check
- loading states on account creation and login
- swipe actions on category rows

## Local Screen Rendering

The app now supports direct screen rendering for onboarding-related states via launch arguments:

```bash
--figma-screen welcome
--figma-screen login
--figma-screen pricing
--figma-screen onboarding-intro
--figma-screen onboarding-profile
--figma-screen onboarding-username
--figma-screen onboarding-income
--figma-screen onboarding-categories
--figma-screen onboarding-account
--figma-screen edit-category-name
--figma-screen edit-category-budget
--figma-screen edit-category-icon
--figma-screen edit-category-color
--figma-screen guide-welcome
--figma-screen guide-backtap
--figma-screen guide-widgets
--figma-screen guide-complete
```

These routes are intended for screenshot capture and Figma reconstruction, and they avoid live navigation dependencies.

## What Still Requires Live Figma Access

This spec defines the structure and tokens, but a live Figma connector is still needed to:

- create the actual Figma pages and frames
- convert repeated UI into Figma components and variants
- wire prototype links directly inside the file
- publish the onboarding page back as a Figma deliverable
