import Foundation
import FirebaseFirestore
import Combine

/// Repository for managing saving goals in Firestore
class SavingGoalRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var savingGoals: [FirestoreModels.SavingGoal] = []
    private var userId: String?
    
    private var listener: ListenerRegistration?
    
    func startListening(userId: String) {
        self.userId = userId
        listener = db.collection("users").document(userId).collection("savingGoals")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    DebugLogger.log("Error fetching saving goals: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let goals = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.SavingGoal.self)
                }
                
                // Sort client-side to handle legacy documents without sortOrder
                self?.savingGoals = goals.sorted { (g1, g2) in
                    let order1 = g1.sortOrder ?? Int.max
                    let order2 = g2.sortOrder ?? Int.max
                    
                    if order1 != order2 {
                        return order1 < order2
                    }
                    return g1.targetDate < g2.targetDate
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
        savingGoals = []
    }
    
    func addSavingGoal(_ goal: FirestoreModels.SavingGoal) async throws {
        guard let userId = userId else { return }
        var newGoal = goal
        // Append to end of list
        let maxOrder = savingGoals.map { $0.sortOrder ?? 0 }.max() ?? -1
        newGoal.sortOrder = maxOrder + 1
        newGoal.createdAt = Date()
        
        // Optimistic Update: Add to local list immediately
        DispatchQueue.main.async {
            self.savingGoals.append(newGoal)
        }
        
        try db.collection("users").document(userId).collection("savingGoals").document().setData(from: newGoal)
        
        // Gamification
        DispatchQueue.main.async {
            GamificationManager.shared.completeMission(id: "goal_getter")
        }
    }
    
    func updateSavingGoal(_ goal: FirestoreModels.SavingGoal) async throws {
        guard let userId = userId, let id = goal.id else { throw NSError(domain: "SavingGoalRepository", code: 400) }
        try db.collection("users").document(userId).collection("savingGoals").document(id).setData(from: goal)
    }
    
    func reorderSavingGoals(_ goals: [FirestoreModels.SavingGoal]) {
        guard let userId = userId else { return }
        
        // Optimistic update
        self.savingGoals = goals
        
        let batch = db.batch()
        for (index, goal) in goals.enumerated() {
            guard let id = goal.id else { continue }
            let ref = db.collection("users").document(userId).collection("savingGoals").document(id)
            batch.updateData(["sortOrder": index], forDocument: ref)
        }
        
        batch.commit { error in
            if let error = error {
                DebugLogger.log("Error reordering goals: \(error)")
            }
        }
    }
    
    /// Distributes savings amount to goals in order (Waterfall)
    func distributeSavings(amount: Double) async throws {
        guard userId != nil else { return }
        
        var remainingAmount = amount
        // Use current local order which should be correct
        let sortedGoals = savingGoals.sorted {
            ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max)
        }
        
        for goal in sortedGoals {
            if remainingAmount <= 0.01 { break } // Float precision check
            
            let needed = goal.targetAmount - goal.currentAmount
            if needed <= 0 { continue }
            
            let allocation = min(remainingAmount, needed)
            var updatedGoal = goal
            updatedGoal.currentAmount += allocation
            
            // This awaits effectively sequentially, ensuring consistency
            try await updateSavingGoal(updatedGoal)
            remainingAmount -= allocation
        }
    }
    
    func deleteSavingGoal(id: String) async throws {
        guard let userId = userId else { return }
        try await db.collection("users").document(userId).collection("savingGoals").document(id).delete()
    }
}
