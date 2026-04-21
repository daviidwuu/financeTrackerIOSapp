# Figma View Spec: Onboarding Welcome

Source:

- `FinanceTracker/Views/Onboarding/WelcomeView.swift`
- `FinanceTracker/DesignSystem.swift`
- `FinanceTracker/Color+Extensions.swift`
- `docs/UI_UX_GUIDE.md`

Target:

- build `Welcome` in Figma first
- keep it visually faithful to the current SwiftUI implementation

## Frame Setup

Create an iPhone mobile frame:

- name: `onboarding/welcome`
- size: `390 x 844`
- fill: `bg/primary`
- clip content: on

Use vertical auto layout on the root frame only if you prefer to keep everything structured. If you do, use:

- direction: vertical
- padding left/right: `24`
- padding top: `0`
- padding bottom: `40`
- item spacing: `0`

The actual visual layout is split into three vertical zones:

1. top spacer
2. centered logo/title block
3. bottom action stack

## Layer Tree

Use this structure:

```text
onboarding/welcome
  bg
  content
    top-spacer
    hero-block
      logo-stack
        logo-circle
        logo-icon-shadow
        logo-icon
      title-block
        brand
        subtitle
    bottom-spacer
    actions
      button-primary
      button-secondary
      pricing-link
```

## Background

- add a full-frame rectangle named `bg`
- fill: `bg/primary`
- send to back

## Main Content Container

Create `content`:

- width: `Fill container`
- height: `Fill container`
- auto layout: vertical
- horizontal alignment: center
- vertical distribution: packed

Set spacing to mimic the SwiftUI structure:

- `top-spacer`: flexible
- `hero-block`: fixed content
- `bottom-spacer`: flexible
- `actions`: fixed content

If you prefer not to use spacer frames, place the `hero-block` visually around center and pin `actions` near the bottom with `40` bottom padding.

## Hero Block

Create `hero-block`:

- auto layout: vertical
- alignment: center
- item spacing: `24`

### Logo Stack

Create `logo-stack`:

- size: `120 x 120`
- position: centered

Inside it:

#### logo-circle

- ellipse
- size: `120 x 120`
- fill: pure white
- shadow:
  - color: white at `30%`
  - blur: `20`
  - y: `10`

#### logo-icon

- use an icon placeholder for `creditcard.fill`
- size: about `50 x 50`
- color: black
- centered inside the circle

The code duplicates the symbol twice, but visually the important result is a single centered black credit-card icon inside the white circle. In Figma, use one clean icon unless you specifically want to mimic the exact stacked implementation artifact.

### Title Block

Create `title-block`:

- auto layout: vertical
- alignment: center
- item spacing: `12`

#### brand

- text: `wym`
- style: `Display / Welcome`
- color: `text/primary`

Suggested style values:

- size: `34`
- weight: `Bold`
- line height: auto or about `41`

#### subtitle

- text: `Master your money with ease`
- style: `Subheadline / Regular`
- color: secondary text
- width: hug or about `220`
- alignment: center

## Action Stack

Create `actions`:

- auto layout: vertical
- width: `Fill container`
- item spacing: `16`

This block should sit above the bottom safe area with about `40` bottom padding.

### Primary Button

Create `button-primary`:

- component: `Button / Primary Capsule / Enabled`
- width: `Fill container`
- height: `50`
- label: `Get Started`

Visuals:

- fill: white
- text: black
- radius: `25`
- shadow:
  - color: white at `30%`
  - blur: `10`
  - y: `5`

### Secondary Button

Create `button-secondary`:

- component: `Button / Secondary Capsule`
- width: `Fill container`
- height: `50`
- label: `I already have an account`

Visuals:

- fill: `surface/card`
- text: `text/primary`
- radius: `25`

### Pricing Link

Create `pricing-link`:

- auto layout: horizontal
- alignment: center
- item spacing: `6`
- top padding from previous button: `4`

Children:

- text: `See plans & pricing`
- chevron-right icon

Text styling:

- style: `Subheadline / Regular`
- color: secondary text

Chevron styling:

- size: `12`
- weight: semibold feel
- color: secondary text

## Spacing Summary

Use these exact values where possible:

- hero block internal spacing: `24`
- title block spacing: `12`
- action stack spacing: `16`
- extra top spacing before pricing link: `4`
- horizontal padding for actions: `24`
- bottom padding: `40`

## Prototype Links

Wire this screen like this:

- `Get Started` -> `onboarding/step-1-intro`
- `I already have an account` -> `onboarding/login`
- `See plans & pricing` -> `onboarding/pricing`

Transition suggestion:

- use `Smart Animate` or simple `Push Left`
- duration around `250ms`

## QA Checklist

Before calling this view done, confirm:

- the background is monochrome, not tinted
- the white circle reads as the hero focal point
- the `wym` wordmark feels visually centered with the subtitle
- the two buttons have clear hierarchy
- the bottom action group has enough breathing room above the safe area
- the overall screen feels airy and premium, not cramped

## Notes From Code

Direct mapping from SwiftUI:

- background uses `Color.backgroundPrimary`
- logo circle is `120 x 120`
- logo/title block spacing is `24`
- title/subtitle block spacing is `12`
- outer hero/action stack spacing is `40`
- bottom action area uses `24` horizontal padding and `40` bottom padding

## After Approval

The next recommended view is:

- `Login`
