# Improvement Notes — wym Finance Tracker

Recorded during frontend/backend separation pass. These are observations only — no files were modified.

---

## Architecture

### 1. Firebase write logic inside `OnboardingView.swift`
**Location:** `Views/Onboarding/OnboardingView.swift`
**Issue:** The account-creation batch commit (Firestore write for user document + initial budgets) lives directly inside the view. This breaks the "views are dumb" principle and makes the view untestable.
**Suggestion:** Extract to `FirebaseManager.createUserAccount(...)` or a dedicated `OnboardingCoordinator`. The view would call a single async function and only handle UI state.

### 2. `CategoryIconView` reads from `appState.budgetRepo` inline
**Location:** `Views/Components/CategoryIconView.swift`
**Issue:** The component resolves its own icon/color by querying `appState.budgetRepo.budgets` directly inside the view body. This creates a hidden dependency on the full AppState graph and makes the component impossible to preview/test without Firebase.
**Suggestion:** Accept `icon: String` and `colorHex: String` as direct parameters (already resolved upstream). The caller can do the lookup. This matches the pattern used by `TransactionRow` (which already resolves category data before rendering).

### 3. `AppState` is a singleton (`static let shared`)
**Location:** `AppState.swift`
**Issue:** Using `AppState.shared` alongside injecting it as `@EnvironmentObject` creates two code paths. Some call sites reach for the singleton directly; others go through the environment. This makes mocking impossible for previews and unit tests.
**Suggestion:** Remove `AppState.shared`. All access should flow through the environment object. For the rare cases that need AppState outside SwiftUI (e.g. `UserResolver`), pass it in the constructor.

### 4. `HapticManager.shared.light()` called inside `ButtonStyles`
**Location:** `Views/Components/ButtonStyles.swift`
**Issue:** Haptic calls inside button styles make the styles impossible to preview on Mac (Designed for iPad / Mac Catalyst) and couple the style to a non-UI concern.
**Suggestion:** Add an optional `onTap: (() -> Void)?` parameter to button styles, or trigger haptics from the button's `action` closure at the call site.

### 5. `GamificationManager.shared` accessed in `AppState`
**Location:** `AppState.swift` (inside `updateStreak`)
**Issue:** `AppState` calls `GamificationManager.shared.completeMission(id:)` directly. This creates a hidden coupling between auth/session management and gamification logic.
**Suggestion:** Emit a notification or use a Combine publisher for streak events. `GamificationManager` can subscribe independently.

---

## UI / Design

### 6. Hard-coded `$0.08` shadow opacity on profile avatar
**Location:** `Views/Profile/ProfileView.swift` & `ProfileComponents.swift`
**Issue:** `.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)` is hard-coded. In dark mode, this shadow is invisible (black on black).
**Suggestion:** Use `.shadow(color: Color.primary.opacity(0.12), ...)` so the shadow adapts to both modes.

### 7. Balance card uses `String(format: "%.2f", ...)` instead of `CurrencyFormatter`
**Location:** `Views/Home/HomeView.swift`
**Issue:** The main balance card formats the amount with a raw format string instead of `CurrencyFormatter.format(amount)`. This bypasses travel-mode currency conversion and locale formatting.
**Suggestion:** Replace with `CurrencyFormatter.format(totalSpent)` / `CurrencyFormatter.format(totalBudget - totalSpent)`.

### 8. `ProfileView` duplicates the avatar layout from `ProfileComponents.ProfileHeaderView`
**Location:** `Views/Profile/ProfileView.swift` lines 29–70
**Issue:** `ProfileView` re-implements the avatar + name + edit-button layout inline instead of using the already-extracted `ProfileHeaderView` component.
**Suggestion:** Use `ProfileHeaderView` directly, removing ~40 lines of duplication.

### 9. `OverlayHeaderView` material composition order
**Location:** `Views/Components/OverlayHeaderView.swift`
**Issue:** The background stacks `Color.backgroundPrimary.opacity(0.85 * progress)` on top of `.ultraThinMaterial.opacity(progress)`. The material is applied via `.background(Group { ... })` inside the already-colored view, which means it renders in the wrong layer order and can look off on some themes.
**Suggestion:** Restructure to: `ZStack { Rectangle().fill(.ultraThinMaterial); Color.backgroundPrimary.opacity(0.85 * progress) }`.

### 10. Missing `accessibilityLabel` on most icon-only buttons
**Location:** Throughout `Views/`
**Issue:** Many icon-only buttons (notification bell, profile circle, trophy button in HomeView header, close/back buttons in modals) lack `.accessibilityLabel(...)`. This is an App Store review risk and breaks VoiceOver support.
**Suggestion:** Add descriptive labels to all `Image(systemName:)`-only buttons.

---

## Performance

### 11. `WalletLogic.calculateSavingsPool` called on every HomeView render
**Location:** `ViewModels/WalletLogic.swift`, called from `HomeView`
**Issue:** The savings pool iterates `allTransactions` (potentially thousands of items) synchronously on the main thread inside a `var body: some View` computed property.
**Suggestion:** Memoize in a `@State` / `@Derived` value updated only when `allTransactions` changes. Or move to a background `Task` with `.task(id:)`.

### 12. `TransactionRepository` maintains four simultaneous Firestore listeners
**Location:** `Repositories/TransactionRepository.swift`
**Issue:** `transactions`, `currentMonthTransactions`, `calendarTransactions`, and `allTransactions` each have their own listener. Firestore charges per read; four overlapping listeners on the same collection is expensive for users with large histories.
**Suggestion:** Maintain one broad listener covering the widest needed window and derive narrower views in-memory.

---

## Security

### 13. `AppConfig.swift` may contain hardcoded API keys
**Location:** `Managers/AppConfig.swift`
**Issue:** Build-time constants file. If any secret keys (RevenueCat, Google Ads IDs) are stored as Swift string literals instead of via `.xcconfig` / environment variables, they are extractable from the compiled binary.
**Suggestion:** Move secrets to `.xcconfig` files (not tracked by git) and access via `Bundle.main.infoDictionary`.

---

## Testing

### 14. Zero unit tests for `WalletLogic`
**Location:** `FinanceTrackerTests/`
**Issue:** `WalletLogic.swift` contains all financial calculations (balance, savings pool, budget utilization, etc.) but the test target appears empty.
**Suggestion:** Add `XCTestCase` covering `calculateNetSpent`, `calculateTotalBudget`, `calculateSavingsPool`, and edge cases (empty arrays, all-income, currency conversion).

---

*Last updated: Frontend/backend separation pass.*
