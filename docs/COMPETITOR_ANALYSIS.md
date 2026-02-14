# Competitor Analysis & Robustness Improvement Plan

## 1. Competitor Landscape: Splitwise vs. wym

### A. Splitwise (The Gold Standard)
**Core Philosophy:** "Trust but Verify."
*   **Edits:** Allows editing almost anything (Amount, Payer, Date, Title).
*   **Notifications:** "David updated the bill 'Dinner' from $50 to $60."
*   **Audit Trail:** Every bill has an "Activity" tab showing a chronological history of changes.
*   **Deletion:** Soft deletes (recoverable). "David deleted 'Dinner'".
*   **Debt Simplification:** Mathematical optimization to reduce number of transactions (A owes B, B owes C -> A owes C).

### B. Tricount
**Core Philosophy:** "Offline & Simple."
*   **Edits:** Updates the balance immediately.
*   **Focus:** Less about "Accepting" splits, more about "Balancing" the group.

### C. wym (Current State)
**Core Philosophy:** "Key & Door" (Cascading CRUD).
*   **Structure:** Personal Transaction (Key) -> Group Transaction / Split Requests (Doors).
*   **Robustness:**
    *   ✅ **Create:** Atomic batch writes ensure data consistency.
    *   ✅ **Delete:** Cascading deletes remove all traces (Key removal closes all Doors).
    *   ⚠️ **Edit:** Updates propagate, but **silently**. No notification, no history.
    *   ⚠️ **Recovery:** Deletion is permanent (Hard Delete).

---

## 2. Identified Gaps & "Key & Door" Refinement

### Gap 1: The "Silent Edit" Problem
**Scenario:** David adds a bill for $50. Alice accepts. David later changes it to $100.
**Current Behavior:** Alice's pending/accepted status might be reset (good), or updated silently. She sees $100 but doesn't know *why* or *when* it changed.
**Fix:** Implement **Edit History (Audit Trail)**.
*   **Key Analogy:** When the Key is reshaped (edited), the Doors should creak (notify/log).

### Gap 2: The "Hard Delete" Risk
**Scenario:** David accidentally deletes a complex group dinner bill.
**Current Behavior:** Gone forever. All splits, all group feed entries vanish.
**Fix:** Consider **Soft Deletes** (Archiving) or at least a robust "Undo" (difficult in distributed systems). *For now, we will focus on preventing accidental deletes via UI confirmation, which is already present.*

### Gap 3: Group vs. Friend Ambiguity
**Scenario:** A bill can be linked to a Group *and* have individual friend splits.
**Refinement:** Ensure the UI clearly distinguishes between "Group Expense" (visible to all group members) and "Direct Split" (visible only to involved parties).

---

## 3. Implementation Plan: Enhancing Robustness

We will focus on **Gap 1 (Silent Edit)** to bring us closer to Splitwise's level of trust.

### A. Data Model: `EditHistory`
We already have `EditRecord` in `FirestoreModels.swift`.
```swift
struct EditRecord: Codable, Identifiable {
    var date: Date
    var editorName: String
    var field: String // "amount", "title"
    var oldValue: String
    var newValue: String
}
```

### B. Logic: `SocialTransactionManager.swift`
We need to modify `createSocialTransaction` (which handles updates) to:
1.  **Fetch Existing Data:** Before writing, compare incoming `transaction` with the existing Firestore document.
2.  **Detect Changes:** Check critical fields (`amount`, `title`, `currency`).
3.  **Append History:** If changed, add an `EditRecord` to the `editHistory` array.
4.  **Propagate:** Ensure this history is saved to both `UserTransaction` and `GroupTransaction`.

### C. UI: `GroupTransactionDetailView`
*   Already implemented to show `(Edited)` and potential history details.

## 4. Why This Improved "Key & Door" is Better
*   **Old Way:** Key turns -> Door opens/closes. (Binary state).
*   **New Way:** Key turns -> Door opens/closes **AND** a log is written "Key turned by David at 10:00 PM".
*   This adds **Accountability** to the **Cascading CRUD**.
