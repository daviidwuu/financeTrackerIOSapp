# wym COO Team Plan

## Role: wym COO
Owns codebase-wide coordination and design consistency for the wym project.

### Responsibilities
- Keep SwiftUI screens visually aligned with the design system.
- Enforce shared spacing, radius, typography, and color tokens.
- Prevent feature drift between Home, Wallet, Social, and Detail flows.
- Coordinate backend and frontend work so UI and data model changes land together.
- Make sure any new UI uses existing design patterns before inventing new ones.

## Specialist Roles

### 1. Backend Coder
**Scope**
- Firebase Cloud Functions in `functions/`
- Firestore-triggered sync logic
- HTTP endpoints and scheduled jobs
- Security-sensitive data consistency logic

**Primary goals**
- Fix backend rules and trigger flows that affect social, split, and transaction states.
- Keep server-side logic authoritative for cross-user updates.
- Ensure backend actions match the app’s expected UI states.

### 2. Frontend Coder
**Scope**
- SwiftUI app code in `FinanceTracker/`
- Navigation, tabs, sheets, and view composition
- Reusable components and design system usage

**Primary goals**
- Make the design system the single source of truth.
- Normalize card layouts, headers, buttons, and spacing.
- Remove one-off UI patterns that conflict with the app’s premium utility style.

### 3. Code Optimiser
**Scope**
- Shared code structure
- Repeated logic in Swift and JavaScript
- Performance, maintainability, and abstraction quality

**Primary goals**
- Reduce duplication across views and managers.
- Extract shared utilities where patterns repeat.
- Improve code clarity without changing behavior.
- Identify unnecessary complexity in state and repository layers.

### 4. Tester
**Scope**
- Unit tests in `FinanceTrackerTests/`
- UI tests in `FinanceTrackerUITests/`
- Backend validation scripts and build logs

**Primary goals**
- Verify critical finance flows: add transaction, budgets, splits, social actions, and recurring processing.
- Catch regressions in design consistency and data integrity.
- Prioritize failure-prone paths from existing logs and audits.

## Current Design Consistency Rules
- Use `AppSpacing`, `AppRadius`, and `AppTypography` instead of hardcoded values.
- Preserve the monochrome core + functional color model.
- Keep Social identity visuals consistent across all screens.
- Use card-based layouts instead of generic Forms where the design system calls for it.
- Keep primary actions tactile, visible, and consistent in placement.

## Known Codebase Focus Areas
- `ContentView.swift` for navigation and global interaction patterns
- `DesignSystem.swift` for reusable UI tokens and component helpers
- `functions/index.js` for backend orchestration
- `docs/DESIGN_GUIDELINES.md` and `docs/UI_UX_GUIDE.md` as the visual source of truth
- Social/backend logic flagged in `docs/SOCIAL_BACKEND_AUDIT.md`

## First-pass Work Order
1. Audit the app for design drift against the design system.
2. Audit backend social/split flows for consistency and permission safety.
3. Identify duplicated or inconsistent UI patterns.
4. Add or strengthen tests around the highest-risk finance flows.
