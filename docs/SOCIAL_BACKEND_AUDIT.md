# Social Backend Analysis & Audit

## Executive Summary
The social module in wym (v2.1) introduces complex interpersonal features (Splits, Groups, Friends). While the architecture is sound (Repositories + Firestore), there are **critical security blocking issues** and **data consistency flaws** that will cause the "Settle Up" feature to fail in production. Additionally, the "Guest Merge" feature presented in the UI is currently a placebo with no backend implementation.

## 1. Critical Flaws (Showstoppers)

### 1.1 `settleUp` Security Violation
**Severity: Critical (Feature Broken)**
*   **Location**: `SocialRepository.swift` -> `settleUp()`
*   **Issue**: The function attempts to update the **Receiver's** private transaction history to mark splits as paid.
    ```swift
    // In settleUp():
    let txRef = db.collection("users").document(receiverId).collection("transactions").document(originalTxId)
    // ...
    try batch.setData(from: updatedTx, forDocument: txRef) 
    ```
*   **Conflict**: `firestore.rules` explicitly denies writing to another user's `transactions` subcollection:
    ```javascript
    match /users/{userId}/transactions/{document=**} { 
      allow read, write: if request.auth.uid == userId;
    }
    ```
*   **Result**: The `batch.commit()` will fail with `permission-denied`. Users will see "Failed to settle up" and be unable to clear debts.
*   **Fix**: Do not update the Creditor's private transaction. Instead, rely *only* on the `SplitRequest` status (which is shared) to calculate balances. If the Creditor needs to see the "Income" transaction in their history, it must be generated via a **Cloud Function** (which runs as Admin) triggered by the `SplitRequest` status change to `paid`.

### 1.2 "Ghost Friend" Data Inconsistency
**Severity: High**
*   **Location**: `FriendRepository.swift` -> `deleteFriend()`
*   **Issue**: The function performs a two-step delete.
    1.  Deletes friend from *Current User's* list (Await).
    2.  Deletes current user from *Friend's* list (Detached Task).
*   **Risk**: If step 1 succeeds but step 2 fails (network, crash), the Friend still sees the Current User as a friend. They can continue sending requests/invites, which the Current User (who deleted them) cannot see or process properly.
*   **Fix**: Move the bi-directional deletion to a **Cloud Function** (`onDocumentDeleted` trigger on the `friends` subcollection) or use a single batch operation if permissions allow (currently they don't allow writing to the friend's subcollection).

## 2. Logic Gaps & Implementation Missing

### 2.1 Fake "Guest Merge" Feature
**Severity: Medium (UX Deception)**
*   **Location**: `SocialDashboardView.swift`
*   **Issue**: When the user searches for a friend who matches an existing Guest name, the app shows a "Merge & Add" alert.
*   **Reality**: Both "Merge & Add" and "Just Add" buttons call the exact same function: `searchAndSendRequest`.
    ```swift
    Button("Merge & Add") { searchAndSendRequest(...) }
    Button("Just Add") { searchAndSendRequest(...) }
    ```
*   **Gap**: There is **no logic** to migrate the Guest's existing debts/transactions to the new Friend account. The Guest remains a separate entity, and the new Friend starts with $0 balance. The user expects the history to transfer.

### 2.2 Case-Sensitive User Search
**Severity: Medium**
*   **Location**: `FriendRepository.swift` -> `searchUsers()`
*   **Issue**: Firestore queries are case-sensitive by default.
    ```swift
    .whereField("username", isEqualTo: username)
    ```
*   **Result**: Searching "David" will not find "david".
*   **Fix**: Store a `username_lowercase` field in the User document and search against that, or ensure the UI forces lowercase input.

## 3. Potential Crashes & Performance

### 3.1 Non-Atomic Batch Construction
**Severity: Medium**
*   **Location**: `SocialRepository.swift` -> `settleUp()`
*   **Issue**: The function performs `await` calls (Network I/O) *inside* the loop where it builds the write batch.
    ```swift
    for doc in pendingSplits.documents {
        // ...
        let txSnapshot = try await txRef.getDocument() // <--- Network Call inside loop
        // ...
        batch.setData(...)
    }
    ```
*   **Impact**:
    1.  **Slowness**: Serial network requests make the operation `O(n)` instead of `O(1)`.
    2.  **Brittleness**: If any single fetch fails, the entire operation aborts.
*   **Fix**: Fetch all necessary data in parallel *before* starting the batch, or rely on Cloud Functions to handle the cascading updates asynchronously.

## 4. Recommended Action Plan

1.  **Immediate**: Modify `settleUp` to **stop** trying to update the receiver's transaction. Only update the `SplitRequest` status to `paid` and create the Payer's "Payment" transaction.
2.  **Backend**: Implement a Cloud Function (`onSplitRequestUpdated`) that detects `status == 'paid'` and securely creates the corresponding "Income" transaction in the Receiver's collection.
3.  **Feature**: Implement the actual `mergeGuestToFriend` logic (re-linking past transactions from `guestId` to `friendId`).
4.  **Fix**: Update `searchUsers` to handle case-insensitivity.
