# wym App Analysis

## 1. Overview
wym is a comprehensive personal finance management iOS application built with **SwiftUI** and **Firebase**. It allows users to track expenses, manage budgets, split bills with friends, and gamify their financial habits. The app follows a cloud-first approach, syncing all data in real-time via Firestore.

## 2. Technical Architecture

### 2.1 Tech Stack
*   **Frontend**: iOS (SwiftUI, Combine)
*   **Backend**: Firebase (Auth, Firestore, Cloud Functions, Messaging, Hosting)
*   **State Management**: Centralized `AppState` (ObservableObject) + Repository Pattern
*   **Architecture Pattern**: MVVM-like (Model-View-ViewModel)

### 2.2 Core Components
*   **`FinanceTrackerApp.swift`**: The app entry point. It initializes Firebase, configures the `NotificationManager` for push notifications, and handles app lifecycle events (background tasks, deep links).
*   **`AppState.swift`**: The global state container. It manages:
    *   Authentication state (User login/logout).
    *   User Profile data (Name, Streak, Settings).
    *   Navigation state (Tab selection, Sheet presentation).
    *   **Repositories**: It holds instances of all data repositories (`TransactionRepository`, `BudgetRepository`, etc.), making them accessible throughout the app via `@EnvironmentObject`.
*   **`ContentView.swift`**: The main UI shell. It manages the tab bar navigation (Home, Social, Wallet) and global floating action buttons (Add Transaction).
*   **Repositories**: Specialized classes (e.g., `TransactionRepository`) that handle CRUD operations with Firestore. They use `Combine` to publish real-time updates to the UI.

## 3. Key Functionality & Design

### 3.1 Authentication & User Management
*   **Design**: Uses Firebase Auth for identity management.
*   **Logic**: `AppState` listens to `Auth.auth().addStateDidChangeListener`. When a user logs in, it automatically initializes all data repositories for that specific `userId`. Anonymous login is supported but distinguished from full accounts.
*   **Gamification**: Tracks user "Streaks" (consecutive days opening the app) stored in `UserProfile`.

### 3.2 Transaction Management
*   **Adding Transactions**: handled by `ContentView.swift` -> `addTransaction()`.
    *   Converts UI form data (`TransactionFormData`) into a `FirestoreModels.TransactionModel`.
    *   Supports: Income/Expense, Custom Categories (with Icons/Colors), Notes, Location (Lat/Long), and **Splits**.
*   **Splitting**: A transaction can contain an array of `Split` objects. Each split links to a Friend or Guest and tracks payment status (`isPaid`, `isAccepted`).
*   **Recurring Transactions**: Users define rules (e.g., "Rent, Monthly").
    *   **Automation**: A Firebase Cloud Function (`processRecurringTransactions`) runs daily to check these rules and automatically creates new transactions when due.

### 3.3 Budgeting
*   **Design**: Users set budgets per category (e.g., "$500/month for Dining").
*   **Logic**:
    *   `CategoryBudget` model stores the limit and frequency.
    *   **Calculation**: `remainingAmount(transactions:)` dynamically filters transactions for the current period (Week/Month/Year) and calculates the remaining balance.
    *   **Alerts**: The app checks budget status after every transaction add. If usage > 80% (configurable), a local notification is triggered via `NotificationManager`.

### 3.4 Social & Splitting (V2.1)
*   **Friends**: Users can send friend requests. Handled by `FriendRequestRepository` and Firebase Functions (`v2_onFriendRequest...`).
*   **Groups**: Users can create expense groups.
*   **Cloud Logic**:
    *   **Notifications**: Firebase Functions trigger push notifications for new requests, invites, and payments.
    *   **Status Sync**: `v2_onSplitRequestUpdated` function ensures that when a split request is paid or declined, the status is synced back to the original `Transaction` document in the sender's data.

### 3.5 Gamification
*   **Streaks**: `AppState` updates the user's streak count daily upon app launch.
*   **Missions**: `GamificationManager` tracks specific actions (e.g., "Widget Watcher") to award badges or points.

## 4. Backend Logic (Firebase Functions)

The backend logic is implemented in `functions/index.js` and handles tasks that require reliability or cross-user coordination:

1.  **`addTransaction` (HTTP)**: Allows external tools (like Siri Shortcuts) to add transactions via a POST request.
2.  **`processRecurringTransactions` (Scheduled)**: Runs every day at 00:01. Scans all recurring rules, checks if they are due, creates the transaction, and updates the `lastProcessedDate`.
3.  **Social Triggers**:
    *   **`v2_onFriendRequest...`**: Sends notifications for requests/accepts. On accept, it creates bi-directional `friend` records in Firestore.
    *   **`v2_onGroupInvitation...`**: Manages group joins. On accept, adds the user to the `Group` members array.
    *   **`v2_onSplitRequestUpdated`**: The most complex logic. It listens for status changes (e.g., "Paid") on a split request and updates the specific `Split` item inside the original `Transaction` document, ensuring the sender sees the updated status.

## 5. Data Models (FirestoreModels.swift)

*   **TransactionModel**: Main record. Includes `splits: [Split]`.
*   **Split**: Sub-model. `{ friendId, amount, isPaid, status }`.
*   **CategoryBudget**: `{ category, totalAmount, frequency }`.
*   **RecurringTransaction**: `{ frequency, nextDueDate, amount }`.
*   **FriendRequest / SplitRequest**: Temporary documents for handshakes.
*   **UserProfile**: `{ streakCount, points, settings }`.

## 6. Architecture Diagram

```mermaid
graph TB
    subgraph "iOS Client (SwiftUI)"
        direction TB
        View[ContentView / Views]
        State[AppState (ObservableObject)]
        Repo[Repositories (Transaction, Budget, Social...)]
        NM[NotificationManager]
        GM[GamificationManager]
        
        View --> State
        State --> Repo
        View --> NM
        View --> GM
    end

    subgraph "Firebase Backend"
        direction TB
        Auth[Firebase Auth]
        Firestore[(Firestore Database)]
        Functions[Cloud Functions (Node.js)]
        Messaging[Cloud Messaging (FCM)]
        
        Repo <--> Firestore
        State <--> Auth
        Functions -- "Triggers (Create/Update)" --> Firestore
        Functions -- "Push Notifications" --> Messaging
        Messaging -- "Remote Notif" --> NM
    end

    subgraph "External"
        Widget[Widgets]
        Shortcuts[Siri Shortcuts]
    end

    %% Data Flow
    Widget -- "Deep Link" --> View
    Shortcuts -- "HTTP Request" --> Functions
    
    %% Specific Logic Flows
    Functions -- "Daily Schedule" --> Firestore
    Functions -- "Friend Request Logic" --> Firestore
```
