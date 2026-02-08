# Developer Guide 🛠️

Welcome to the `wym` (FinanceTracker) codebase! This guide is designed to help you understand the architecture, tech stack, and key workflows of the application so you can start contributing quickly.

---

## 📚 Tech Stack

-   **Language**: Swift 5.0+
-   **UI Framework**: SwiftUI
-   **Backend**: Firebase
    -   **Authentication**: Firebase Auth (Anonymous & Email/Password)
    -   **Database**: Cloud Firestore (NoSQL)
    -   **Serverless**: Cloud Functions (for scheduled tasks like recurring transactions)
-   **State Management**: `ObservableObject` (ViewModels) + `EnvironmentObject` (AppState)
-   **Local Storage**: `UserDefaults` (Settings, Widget Data)
-   **Extensions**: WidgetKit (Home & Lock Screen Widgets)

---

## 🏗️ Architecture

The app follows a **MVVM (Model-View-ViewModel)** pattern, but with a practical "Service-Repository" layer for Firebase interactions.

### High-Level Data Flow

1.  **View**: Displays data and capturing user intent (e.g., `AddTransactionView`).
2.  **ViewModel** (Optional): Manages local logic for complex views.
3.  **Repository/Manager**: Single source of truth for data. fetches from Firestore and publishes changes via `@Published` properties.
    -   *Example*: `TransactionRepository` listens to Firestore and updates its `transactions` array.
4.  **Firestore**: The cloud database.

### Core Singletons

We use singleton Managers for global services:

-   `AppState.shared`: Global app state (User login status, active tab, etc.).
-   `FirebaseManager.shared`: Handling Auth and low-level Firebase config.
-   `LocationManager.shared`: Handles GPS and Reverse Geocoding for "Travel Mode".
-   `GamificationManager.shared`: Tracks user points, missions, and rewards.
-   `WidgetDataManager.shared`: Bridges data between the main app and Widget via App Groups (`UserDefaults`).

---

## 📂 Folder Structure

```
FinanceTracker/
├── Features/             # Feature-specific Views and Components
│   ├── Gamification/     # Missions, Rewards
│   ├── Transaction/      # Add/Edit Transaction flows
│   └── ...
├── Views/                # Core Application Views
│   ├── Home/             # Dashboard
│   ├── Wallet/           # Budget & Savings interfaces
│   └── ...
├── ViewModels/           # (Optional) Specific business logic
├── Models/               # Data structures (Transaction, Mission, etc.)
├── Utilities/            # Helper Managers (MigrationManager)
├── Utils/                # Core Utilities (WidgetDataManager, Extensions)
└── FinanceTrackerApp.swift # App Entry Point
```

---

## 🔑 Key Workflows

### 1. Authentication & Onboarding
-   **Entry Point**: `FinanceTrackerApp.swift` checks `AppState.isUserLoggedIn`.
-   **Flow**: `WelcomeView` -> `Login/Signup` -> `OnboardingView` (if new) -> `ContentView`.
-   **Data**: User profile is created in `users/{userId}` collection.

### 2. Transaction Flow (The Core)
-   **Create**: `AddTransactionView` captures input.
-   **Save**: Calls `TransactionRepository.addTransaction`.
-   **Gamification Hook**: Adding a transaction triggers `checkStreak()` and potential missions (e.g., "Streak Starter").
-   **Widget Update**: `TransactionRepository` calculates daily spend and calls `WidgetDataManager.saveDailySpend` to update the lock screen immediately.

### 3. The "Vault" System
-   **Concept**: Unspent budget moves to a "Vault".
-   **Implementation**:
    -   Budgets are stored in `budgets` subcollection.
    -   Transactions are summed up against these budgets.
    -   Surplus is calculated dynamically in `WalletView` (or via Cloud Functions for month-end sweep).

### 4. Travel Mode ✈️
-   **Trigger**: User enables "Travel Mode" in Profile OR `LocationManager` detects a new country.
-   **Logic**: `CurrencyManager` fetches rates using an API (or cached values).
-   **Storage**: Transactions store the `originalAmount` and `currencyCode`, but `amount` is always converted to the Home Currency for consistent reporting.

### 5. Widgets
-   **Data Sharing**: Uses `UserDefaults(suiteName: "group.com.wu.FinanceTracker")`.
-   **Update Loop**: When data changes in `TransactionRepository`, we write to the shared group and call `WidgetCenter.shared.reloadAllTimelines()`.

---

## 🧪 Testing & Verification

-   **Unit Tests**: Located in `FinanceTrackerTests`.
-   **UI Tests**: Located in `FinanceTrackerUITests`.
-   **Manual Testing**: Important for Haptics and Animations which are hard to automate.

---

## 🚀 Getting Started for Devs

1.  Ensure you have the `GoogleService-Info.plist` (ask the project lead if missing).
2.  Install CocoaPods (if used) or SPM packages.
3.  Build and Run on a physical device for the best Haptic experience.
