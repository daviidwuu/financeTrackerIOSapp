# Monetization & Paywall Implementation Plan

## 1. Current State Analysis

The app currently has a hybrid monetization structure with partial implementation:

*   **Advertisements (Ready)**: AdMob is integrated and functional. Banners are displayed for non-premium users.
*   **Paywall UI (Ready)**: `SubscriptionWizardView` provides a complete "Gold/King" themed interface with Annual ($29.99) and Monthly ($2.99) plans.
*   **Subscription Logic (Missing)**:
    *   RevenueCat SDK is included in the project dependencies but not initialized.
    *   No code exists to fetch products, handle purchases, or restore transactions.
    *   The "Subscribe Now" button in the Paywall is a placeholder.
*   **Premium State (Inactive)**: `AppState.isPremiumUser` exists but remains permanently `false`, meaning all users currently see ads and no one can upgrade.

## 2. Readiness Assessment

**Overall Readiness: 40%**

*   **UI/UX**: 90% (Paywall looks good, just needs wiring).
*   **Infrastructure**: 20% (SDK present, but not configured).
*   **Logic**: 0% (No purchase handling).

**Conclusion**: The app is **not ready** for monetization. We cannot submit to the App Store without functional IAP restoration and purchase logic, or we risk rejection.

## 3. Implementation Steps

### Phase 1: Configuration & Initialization
- [x] **Setup RevenueCat**:
    - [ ] Create a Project and App in the RevenueCat Dashboard.
    - [ ] Configure Apple Small Business Program (if applicable).
    - [ ] Set up Products (Identifiers: `finance_tracker_monthly`, `finance_tracker_annual`).
    - [ ] Generate a Public API Key.
- [x] **Initialize SDK**:
    - [x] Add `Purchases.configure(withAPIKey: "YOUR_API_KEY")` in `FinanceTrackerApp.swift`.
    - [x] Enable debug logs for development.

### Phase 2: Purchase Logic
- [x] **Create `PurchaseManager`**:
    - [x] A singleton class to handle RevenueCat interactions.
    - [x] Methods: `fetchOfferings()`, `purchase(package:)`, `restorePurchases()`.
- [x] **Integrate with AppState**:
    - [x] Listen to `Purchases.shared.customerInfoStream`.
    - [x] Update `AppState.shared.isPremiumUser` based on active entitlements (Entitlement ID: `premium`).

### Phase 3: UI Connection
- [x] **Wire up `SubscriptionWizardView`**:
    - [x] Fetch real prices and currency symbols from RevenueCat (don't hardcode "$2.99").
    - [x] Connect "Subscribe Now" button to `PurchaseManager.purchase()`.
    - [x] Add a "Restore Purchases" button (Critical for App Review).
- [ ] **Testing**:
    - [ ] Use StoreKit Configuration File (`.storekit`) for local testing.
    - [ ] Verify `isPremiumUser` toggles correctly and removes ads.

## 4. Next Steps

1.  **Do you have a RevenueCat account?** If not, we need to set one up or use a mock environment for now.
2.  **App Store Connect**: We need to define the In-App Purchase products in App Store Connect to match RevenueCat.
3.  **Execute Phase 1 & 2**: I can start by creating the `PurchaseManager` and setting up the code structure, even without a live API key (using a placeholder).

## 5. Required Information
To proceed fully, I will eventually need:
*   RevenueCat Public API Key.
*   Exact Product Identifiers used in App Store Connect (e.g., `com.yourapp.monthly`, `com.yourapp.annual`).
