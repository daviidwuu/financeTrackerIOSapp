# 📋 Pre-coding Design Readiness Checklist

Complete these Figma tasks **before** touching the code to avoid UI drift and implementation blockers.

## 1. Global Tokens (The "DNA")
- [ ] **Color Palette**: Document "System" vs. "Alternative Theme" variants.
- [ ] **Typography**: Define "Rounded" vs. "Default" font variants (matching `DesignSystem.swift`).
- [ ] **Spacing Grid**: Set Figma "Nudge Amount" to 4px; use `AppSpacing` values only.

## 2. Stateful Components (The "Logic")
- [ ] **Loading States**: Design "Skeleton" loaders or "Spinner" overlays for lists and buttons.
- [ ] **Empty States**: Design all empty variants (No Friends, No Transactions, No Savings).
- [ ] **Error Feedbacks**: Design the `ErrorBanner` for field level vs. top-of-screen alerts.
- [ ] **Interaction States**: define "Pressed" scale levels for all interactive elements.

## 3. Navigation & Scaffolding (The "Skeleton")
- [ ] **Progress Indicators**: Define the Onboarding Progress Bar (active vs. inactive capsules).
- [ ] **Header Transitions**: Design how headers collapse from "Big Root" to "Sticky Nav" style.
- [ ] **Safe Areas**: Ensure all screens account for iOS Notch/Dynamic Island heights.

## 4. Assets & Icons (The "Visuals")
- [ ] **SF Symbols Inventory**: List all symbols used (e.g., `flame.fill`, `trophy.fill`) and ensure they are ready to be pasted as vectors.
- [ ] **Premium Visuals**: Design how "Locked" states differ (yellow lock icons, dimmed opacity).

## 5. Viewport Edge Cases
- [ ] **Keyboard State**: Design layouts with the keyboard visible (e.g., in `OnboardingView`).
- [ ] **Multi-Currency**: Ensure layouts work with long currency strings (e.g., "1,234.56 USD").
