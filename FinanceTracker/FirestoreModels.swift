import Foundation
import FirebaseFirestore

/// Namespace for all Firestore-persisted model types.
/// Domain models are defined in separate files via extension:
///   TransactionModels.swift  — SplitStatus, Split, EditRecord, RecurringTransaction, TransactionModel
///   GroupModels.swift        — Group, GroupTransaction, GroupInvitation
///   FriendModels.swift       — Guest, FriendRequest, Friend, SplitRequest
///   BudgetModels.swift       — CategoryBudget, SavingGoal
///   UserModels.swift         — UserProfile, Reward, Redemption
enum FirestoreModels {}
