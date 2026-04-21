# FinanceTracker Onboarding Figma Playbook

Use this when manually rebuilding the onboarding experience in Figma.

This is the fastest practical order:

1. Create the Figma pages
2. Add foundations
3. Build shared components
4. Assemble the onboarding screens
5. Wire the prototype

If you want the full source-faithful mapping, keep this doc open alongside:

- `docs/FIGMA_ONBOARDING_CONVERSION_SPEC.md`

## 1. Create Pages

Create these pages:

1. `00 Foundations`
2. `01 Components`
3. `02 Onboarding`

Inside `02 Onboarding`, group frames into these sections:

- `Entry`
- `Wizard`
- `Category Sheet`
- `Post Guide`

## 2. Add Foundations

### Color styles or variables

Create these first:

- `bg/primary`
- `text/primary`
- `surface/card`
- `surface/card-secondary`
- `brand/primary`
- `state/success`
- `state/error`
- `category/orange`
- `category/blue`
- `category/red`
- `category/purple`
- `category/indigo`
- `category/yellow`
- `category/cyan`

Map them from code:

- `backgroundPrimary`
- `textPrimary`
- `cardBackground`
- `secondaryCardBackground`
- `AppColors.brandPrimary`
- `AppColors.functionalIncome`
- `AppColors.functionalExpense`

### Typography styles

Create text styles for:

- `Display / Welcome`
- `Hero / 32 Rounded Bold`
- `Hero / 28 Rounded Bold`
- `Input / 64 Rounded Bold`
- `Headline / Semibold`
- `Subheadline / Regular`
- `Body / Regular`
- `Caption / Regular`

### Spacing tokens

Use these values consistently:

- `4`
- `8`
- `16`
- `20`
- `24`
- `32`

### Radius tokens

Use these values consistently:

- `12`
- `16`
- `20`
- `25`
- `28`

## 3. Build Components

Build these in `01 Components` before assembling screens.

### Buttons

- `Button / Primary Capsule / Enabled`
- `Button / Primary Capsule / Disabled`
- `Button / Secondary Capsule`
- `Button / Circle Back`
- `Button / Text Link`

Specs:

- primary height `50`
- capsule radius `25`
- disabled uses `surface/card-secondary`
- back button is `50 x 50`

### Inputs

- `Input / Email`
- `Input / Password`
- `Input / Large Centered Text`
- `Input / Currency`

Specs:

- standard fields use icon left, padded row, `surface/card`
- profile and username inputs are giant centered text only
- income field is `$` + numeric input row

### Progress

- `Progress / 6-Step`
- `Progress / 4-Step`

Make the fill state swappable so you can duplicate frames quickly.

### Cards and rows

- `Row / Category`
- `Card / Pricing / Default`
- `Card / Pricing / Selected`
- `Card / Widget`
- `Row / Numbered Instruction`

### Overlays

- `Overlay / Swipe Guide`

This should include:

- dimmed scrim
- demo category row
- right-edit state
- left-delete state
- instructional caption

## 4. Build Screens

Use iPhone width. If you want a solid starting point, use a mobile frame around `390 x 844`.

### Entry frames

Create these frames:

1. `Welcome`
2. `Login`
3. `Plans & Pricing`

#### Welcome

Top to bottom:

- full background
- logo circle cluster
- `wym`
- subtitle
- `Get Started`
- `I already have an account`
- `See plans & pricing`

#### Login

Top to bottom:

- title and subtitle
- email input
- password input
- forgot-password link
- optional error row
- bottom `Log In`

#### Plans & Pricing

Top to bottom:

- premium chip `king`
- supporting copy
- feature rows
- annual plan card
- monthly plan card
- fixed bottom CTA
- legal copy

### Wizard frames

Create these frames:

1. `Onboarding / Intro`
2. `Onboarding / Profile`
3. `Onboarding / Username`
4. `Onboarding / Income`
5. `Onboarding / Categories`
6. `Onboarding / Account`

All six screens share:

- background fill
- top progress bar
- bottom sticky action area

#### Intro

- blue concentric hero icon
- title
- supporting copy
- login text link
- CTA `Continue`

#### Profile

- title
- subtitle
- large centered name input
- back + continue controls

#### Username

- title
- subtitle
- large centered username input
- one validation state underneath

Create variants for these validation states:

- checking
- available
- taken
- too short

#### Income

- green concentric hero icon
- title
- `$` + amount input
- helper caption

#### Categories

- title
- subtitle
- list of seeded category rows
- add category button

Seed these rows:

- Food & Drink
- Transport
- Bills
- Shopping
- Entertainment

Also create two companion frames:

- `Onboarding / Categories / Swipe Right`
- `Onboarding / Categories / Swipe Left`

These make prototype teaching easier.

#### Account

- title
- subtitle
- email input
- password input
- optional error caption
- primary CTA `Create Account`

### Category sheet frames

Create these frames:

1. `Category Sheet / Name`
2. `Category Sheet / Budget`
3. `Category Sheet / Icon`
4. `Category Sheet / Color`

Each frame should include:

- drag handle
- top overlay header
- step title
- sticky CTA

Step-specific content:

- name: large text input
- budget: large numeric field with helper text
- icon: grid of circular icon options
- color: grid of circular color options

### Post-guide frames

Create these frames:

1. `Guide / Welcome`
2. `Guide / Back Tap`
3. `Guide / Widgets`
4. `Guide / Complete`

#### Guide / Welcome

- green check hero
- `All Set!`
- supporting copy
- `Next`
- `Skip`

#### Guide / Back Tap

- blue tap icon
- title
- subtitle
- four numbered instruction rows

#### Guide / Widgets

- purple widgets icon
- title
- subtitle
- three widget cards
- numbered `How to Add` section

#### Guide / Complete

- yellow sparkles icon
- `You're All Set!`
- supporting copy
- CTA `Get Started`

## 5. Prototype Wiring

Wire these interactions in Prototype mode:

- `Welcome -> Get Started -> Onboarding / Intro`
- `Welcome -> I already have an account -> Login`
- `Welcome -> See plans & pricing -> Plans & Pricing`
- wizard `Continue` through all six onboarding frames
- wizard back button to previous frame
- categories row tap to `Category Sheet / Name`
- category sheet `Next` through steps 1 to 4
- guide `Next` across all four guide frames
- guide `Skip` from steps 1 to 3 to `Guide / Complete`
- guide `Get Started` can end the flow

For swipe interactions:

- use hotspots from `Categories` to `Categories / Swipe Right`
- use hotspots from `Categories` to `Categories / Swipe Left`

## 6. Suggested Naming

Use these names so the file stays easy to automate later:

- `onboarding/welcome`
- `onboarding/login`
- `onboarding/pricing`
- `onboarding/step-1-intro`
- `onboarding/step-2-profile`
- `onboarding/step-3-username`
- `onboarding/step-4-income`
- `onboarding/step-5-categories`
- `onboarding/step-6-account`
- `onboarding/category-sheet-step-1-name`
- `onboarding/category-sheet-step-2-budget`
- `onboarding/category-sheet-step-3-icon`
- `onboarding/category-sheet-step-4-color`
- `onboarding/guide-step-1-welcome`
- `onboarding/guide-step-2-backtap`
- `onboarding/guide-step-3-widgets`
- `onboarding/guide-step-4-complete`

## 7. Useful Local Preview Commands

The app supports direct preview routes for onboarding screens.

After installing the debug app into the simulator, launch with:

```bash
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen welcome
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen login
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen pricing
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen onboarding-intro
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen onboarding-profile
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen onboarding-username
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen onboarding-income
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen onboarding-categories
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen onboarding-account
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen edit-category-name
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen edit-category-budget
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen edit-category-icon
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen edit-category-color
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen guide-welcome
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen guide-backtap
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen guide-widgets
xcrun simctl launch booted com.wu.FinanceTracker --args --figma-screen guide-complete
```

Then capture with:

```bash
xcrun simctl io booted screenshot /tmp/onboarding.png
```

## 8. Paste-Ready Figma Agent Prompt

If you are using another agent workflow that can write to Figma, paste this:

```text
Recreate the FinanceTracker onboarding experience 1:1 in Figma from the local codebase.

Use these pages:
- 00 Foundations
- 01 Components
- 02 Onboarding

Build shared components first:
- wizard progress bars
- primary capsule button
- secondary capsule button
- back circle button
- icon text field
- secure field
- category row
- pricing card
- widget card
- numbered instruction row
- category swipe guide overlay

Then build these frames:
- Welcome
- Login
- Plans & Pricing
- Onboarding Intro
- Onboarding Profile
- Onboarding Username
- Onboarding Income
- Onboarding Categories
- Onboarding Account
- Category Sheet Name
- Category Sheet Budget
- Category Sheet Icon
- Category Sheet Color
- Guide Welcome
- Guide Back Tap
- Guide Widgets
- Guide Complete

Match the existing codebase exactly:
- premium utility visual language
- monochrome foundation
- rounded cards and capsule controls
- blue, green, and red semantic accents
- large rounded hero typography for onboarding
- sticky bottom actions

Use the source files:
- docs/FIGMA_ONBOARDING_CONVERSION_SPEC.md
- docs/FIGMA_ONBOARDING_FIGMA_PLAYBOOK.md
- FinanceTracker/Views/Onboarding/*
- FinanceTracker/Views/Profile/SubscriptionView.swift
- FinanceTracker/DesignSystem.swift
- FinanceTracker/Color+Extensions.swift
```
