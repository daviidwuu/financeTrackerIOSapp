# App Robustness & Scalability Report

## 1. Implemented Improvements

### A. Data Consistency: "Fan-Out" Profile Updates
**Problem:** When a user changes their name or avatar, their friends, groups, and pending bills still show the old information. This creates confusion ("Who is 'User123'?").
**Solution:** Implemented a new Cloud Function trigger `v2_onUserUpdated` in `functions/index.js`.
**How it works:**
1.  **Detects Change:** Watches for updates to `users/{userId}`.
2.  **Filters:** Only runs if `name`, `username`, or `avatarColor` changes.
3.  **Fans Out:**
    *   **Friends:** Updates the denormalized friend list for all friends.
    *   **Groups:** Updates the `memberNames` map in all groups the user belongs to.
    *   **Transactions:** Updates `fromName` or `toName` in all *Active* (Pending/Accepted) split requests.
**Result:** The app feels "live" and consistent. No more stale names.

### B. Data Safety: "Soft Delete" (Archiving)
**Problem:** Accidental deletion of a complex group dinner bill is catastrophic. Data is gone forever.
**Solution:** Modified `SocialTransactionManager.swift` to implement an "Archive-First" strategy.
**How it works:**
1.  **Before Deleting:** When `deleteSocialTransaction` is called...
2.  **Copy:** The transaction and its splits are copied to `archived_transactions` and `archived_split_requests` collections.
3.  **Delete:** Only *after* the copy is prepared (in the same batch), the original is deleted.
**Result:** Robust against user error. Support can manually restore data if needed.

---

## 2. Recommendations for Future Scaling

### A. Idempotency (Backend)
**Why:** Cloud Functions guarantee "at least once" delivery. Rarely, an event might fire twice.
**Recommendation:** Implement an idempotency check using `event.id`.
```javascript
const eventRef = db.collection('processed_events').doc(event.id);
const doc = await eventRef.get();
if (doc.exists) return; // Already processed
await eventRef.set({ processedAt: new Date() });
```

### B. "Nudge" Feature (UX)
**Why:** Intuitive social finance needs communication.
**Recommendation:** Add a "Nudge" button on unpaid splits.
*   **Logic:** Updates `lastNudgedAt` timestamp on the split request.
*   **Trigger:** Cloud Function sends a polite push notification ("David is reminding you about 'Dinner'").
*   **Rate Limit:** Prevent spam (e.g., max 1 nudge per 24h).

### C. Offline Queue (UX/Robustness)
**Why:** Users travel and may have spotty internet.
**Recommendation:** While Firestore handles offline persistence well, complex batch logic can fail if the app is killed before sync.
*   **Strategy:** Build a local "PendingAction" queue in Swift (CoreData or Realm) that retries critical operations (like "Create Transaction") until confirmed success.

### D. Automated Testing (CI/CD)
**Why:** As logic grows (Cascading CRUD, Fan-out), manual testing becomes risky.
**Recommendation:**
1.  **Unit Tests:** Use `jest` for Cloud Functions logic.
2.  **Integration Tests:** Use Firebase Emulators to test the full "Create Transaction -> Trigger Notification" flow.

---

## 3. Summary
The app has moved from a "Prototype" state to a "Production-Ready" architecture with the addition of **Audit Trails**, **Profile Consistency**, and **Data Archiving**.
