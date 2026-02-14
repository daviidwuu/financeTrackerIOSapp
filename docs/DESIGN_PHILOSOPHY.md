# wym Design Philosophy & Component Standards

This document outlines the core design philosophy and specific implementation patterns used in the high-interaction views of the wym app.

---

## 1. Core Philosophy: "Premium Utility"

The wym design system is built on the principle of **Premium Utility**. We avoid standard iOS "Form" and "List" styles (which can feel utility-heavy and uninspired) in favor of **Custom Card-Based Architectures**.

### Key Pillars:
1.  **Monochromatic Foundation**: Using `Black`, `White`, and customized `SystemGrays` for structural elements.
2.  **Functional Vibrancy**: High-saturation colors are strictly reserved for **Categories** and **Action Contexts** (Income vs. Expense).
3.  **Physical Depth**: Using shadows and distinct radii (`AppRadius.medium`—16pt) to make components feel like physical cards on a surface.
4.  **Haptic Affirmation**: Every logical transition or selection is paired with a specific `HapticManager` feedback level.

---

## 2. View-Specific Designs

### **A. TransactionDetailView (The Interactive Dashboard)**
Instead of a static receipt, this view acts as a multi-functional "Summary Card."

*   **Hero Emphasis**: The amount and category are grouped in a "Hero Area" at the top. It uses a 15% opacity tint of the category color for the background to create a "glow" that feels soft, not jarring.
*   **Integrated Map**: The map is not a standalone section; it is integrated as the **header of the Details Card**. This visually links the "Where" of a transaction to the "What" (Category) and "When" (Date).
*   **High-Contrast Actions**: The "View Split Details" button uses **Inverted Monochrome** (Black text on White background in Dark Mode). This ensures the primary user goal—managing social debt—is always the most visible element on the screen.
*   **Shadow Strategy**: We use `Color.black.opacity(0.2)` consistently to create depth without "glow" in dark mode.

### **B. SplitConfigurationView (The Multi-Step Wizard)**
This view handles complex mathematical distribution with a simple, guided interface.

*   **Guided Progression**: It breaks the process into two logical stages: **Selection** (Who is involved?) and **Distribution** (How much do they owe?).
*   **Sticky Action Bar**: The primary action button ("Next" or "Save Changes") is pinned to the bottom using `.safeAreaInset`. This creates a floating effect that keeps the primary goal reachable regardless of scroll depth.
*   **Validation States**: The action bar backgrounds dim and the text changes to `.secondary` when requirements (like selecting at least one person) aren't met, providing silent but clear guidance.
*   **Identity Consistency**: Users and Groups appear with the *exact* same visual identity (colors, icons) as they do in the Social Tab, reducing cognitive load when selecting recipients.

### **C. GroupCreationWizardView (The Identity Builder)**
Created to make group onboarding feel like creating a "Brand."

*   **Visual Progress**: Uses a **Capsule-based progress bar** at the top. This provides a clear "light at the end of the tunnel" for multi-step data entry.
*   **Live Preview**: In the "Styling" step, the group's icon and name are shown in a live preview card. This immediate feedback loop encourages users to spend more time customizing their group.
*   **Interactive Grids**: Styling options (Colors/Icons) are presented in a `LazyVGrid` with significant spacing (`AppSpacing.element`—16pt) to ensure hit areas are large and "tappable."

---

## 3. Geometric Constants (Implementation Reference)

| Type | Constant | Value | UI Feel |
| :--- | :--- | :--- | :--- |
| **Radius** | `AppRadius.medium` | 16pt | Friendly, modern cards. |
| **Radius** | `AppRadius.button` | 25pt | Professional "Capsule" feel for actions. |
| **Spacing** | `AppSpacing.margin` | 20pt | Breathable, edge-to-edge comfort. |
| **Spacing** | `AppSpacing.section` | 32pt | Clear logical separation between topics. |

---

## 4. Dark Mode Strategy
wym does not simply invert colors.
*   **Backgrounds**: Truly `Black` (`#000000`) for OLED efficiency.
*   **Surfaces**: `SecondarySystemBackground` for card elevation.
*   **Text**: High-contrast white for primary, 60% opacity for metadata.
*   **Functional buttons**: Solid `White` backgrounds for primary actions to pierce through the dark theme.
