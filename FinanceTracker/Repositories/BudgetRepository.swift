import Foundation
import FirebaseFirestore
import Combine
import WidgetKit

/// Repository for managing budgets in Firestore
class BudgetRepository: ObservableObject {
    private let db = Firestore.firestore()
    @Published var budgets: [FirestoreModels.CategoryBudget] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var userId: String?
    private var isCreatingIncomeDefault = false
    
    private var listener: ListenerRegistration?
    
    // FIX #20: Clean up listener on deallocation
    deinit {
        listener?.remove()
    }
    
    func startListening(userId: String) {
        self.userId = userId
        // Only show loading if we don't have any data yet (Stale-While-Revalidate)
        if budgets.isEmpty {
            self.isLoading = true
        }
        self.errorMessage = nil
        
        // Listen to ALL budgets for this user (Permanent Budget Model)
        listener = db.collection("users").document(userId).collection("budgets")
            .order(by: "category")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error fetching budgets: \(error.localizedDescription)"
                    DebugLogger.log("Error fetching budgets: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No budgets found."
                    return
                }
                
                self.errorMessage = nil
                
                let allBudgets = documents.compactMap { document in
                    try? document.data(as: FirestoreModels.CategoryBudget.self)
                }
                
                // Deduplicate: Keep only the latest budget per category
                // Group by category
                let grouped = Dictionary(grouping: allBudgets, by: { $0.category })
                
                let uniqueBudgets = grouped.values.compactMap { budgets -> FirestoreModels.CategoryBudget? in
                    // Sort by createdAt descending (or monthStartDate if created same time)
                    return budgets.sorted { (b1, b2) in
                         if b1.createdAt == b2.createdAt {
                             return b1.monthStartDate > b2.monthStartDate
                         }
                         return b1.createdAt > b2.createdAt
                    }.first
                }
                
                // FIX #8: Clean up duplicate budgets from Firestore
                // (previously they accumulated but were only hidden client-side)
                let duplicateIds = grouped.values.flatMap { budgets -> [String] in
                    let sorted = budgets.sorted { (b1, b2) in
                        if b1.createdAt == b2.createdAt {
                            return b1.monthStartDate > b2.monthStartDate
                        }
                        return b1.createdAt > b2.createdAt
                    }
                    return sorted.dropFirst().compactMap { $0.id } // IDs of duplicates to delete
                }
                
                if !duplicateIds.isEmpty {
                    Task { [weak self] in
                        guard let self = self, let uid = self.userId else { return }
                        let batch = self.db.batch()
                        for id in duplicateIds {
                            let ref = self.db.collection("users").document(uid).collection("budgets").document(id)
                            batch.deleteDocument(ref)
                        }
                        try? await batch.commit()
                        DebugLogger.log("Cleaned up \(duplicateIds.count) duplicate budgets")
                    }
                }
                
                self.budgets = uniqueBudgets.sorted(by: { $0.category < $1.category })
                
                // Update Widget Data
                self.updateWidgetData(budgets: uniqueBudgets)
                
                // Ensure default "Income" category exists (if not present in unique list)
                if !uniqueBudgets.contains(where: { $0.category == "Income" }), !self.isCreatingIncomeDefault {
                    self.isCreatingIncomeDefault = true
                    Task { [weak self] in
                        guard let self = self else { return }
                        // Use start of current month
                        let calendar = Calendar.current
                        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
                        await self.createDefaultIncomeCategory(userId: userId, monthStartDate: startOfMonth)
                        self.isCreatingIncomeDefault = false
                    }
                }
            }
    }
    
    private func createDefaultIncomeCategory(userId: String, monthStartDate: Date) async {
        let incomeBudget = FirestoreModels.CategoryBudget(
            category: "Income",
            totalAmount: 0, 
            icon: "plus.circle.fill",
            colorHex: "#34C759", // System Green
            frequency: "Monthly",
            type: "income",
            userId: userId,
            monthStartDate: monthStartDate,
            createdAt: Date()
        )
        
        do {
            try await addBudget(incomeBudget)
        } catch {
            DebugLogger.log("Failed to create default Income category: \(error)")
        }
    }
    
    func stopListening() {
        listener?.remove()
        userId = nil
        budgets = []
        isCreatingIncomeDefault = false
    }
    
    func addBudget(_ budget: FirestoreModels.CategoryBudget) async throws {
        guard let userId = userId else { return }
        var newBudget = budget
        newBudget.createdAt = Date()
        try db.collection("users").document(userId).collection("budgets").document().setData(from: newBudget)
        
        // Gamification
        DispatchQueue.main.async {
            GamificationManager.shared.completeMission(id: "budget_beginner")
            GamificationManager.shared.completeMission(id: "personalizer")
        }
    }
    
    func updateBudget(_ budget: FirestoreModels.CategoryBudget) async throws {
        guard let userId = userId, let id = budget.id else { throw NSError(domain: "BudgetRepository", code: 400) }
        try db.collection("users").document(userId).collection("budgets").document(id).setData(from: budget)
    }
    
    // Delete all budgets with the same category name to prevent "zombies"
    func deleteBudget(_ budget: FirestoreModels.CategoryBudget) async throws {
        guard let userId = userId else { return }
        
        // Find all docs with this category
        let snapshot = try await db.collection("users").document(userId).collection("budgets")
            .whereField("category", isEqualTo: budget.category)
            .getDocuments()
            
        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }
    

    
    private func updateWidgetData(budgets: [FirestoreModels.CategoryBudget]) {
        // Calculate Total Monthly Budget (excluding Income)
        let totalBudget = budgets
            .filter { $0.type == "expense" }
            .reduce(0) { sum, budget in
                var monthlyAmount = budget.totalAmount
                
                // Normalize frequency to Monthly
                switch budget.frequency {
                case "Weekly":
                    monthlyAmount = budget.totalAmount * 52.0 / 12.0
                case "Bi-Weekly":
                    monthlyAmount = budget.totalAmount * 26.0 / 12.0
                case "Yearly":
                    monthlyAmount = budget.totalAmount / 12.0
                default: // "Monthly" or others
                    monthlyAmount = budget.totalAmount
                }
                
                return sum + monthlyAmount
            }
            
        WidgetDataManager.shared.saveMonthlyBudget(totalBudget)
    }
    func checkAndCopyBudgets(userId: String) async {
        let calendar = Calendar.current
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        
        let db = Firestore.firestore()
        let collection = db.collection("users").document(userId).collection("budgets")
        
        do {
            // 1. Check if budgets exist for current month
            let currentSnapshot = try await collection
                .whereField("monthStartDate", isEqualTo: currentMonthStart)
                .limit(to: 1)
                .getDocuments()
            
            if !currentSnapshot.documents.isEmpty {
                return // Budgets already exist for this month
            }
            
            // 2. Find the most recent previous month with budgets
            let lastBudgetSnapshot = try await collection
                .order(by: "monthStartDate", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            guard let lastBudgetDoc = lastBudgetSnapshot.documents.first,
                  let lastBudget = try? lastBudgetDoc.data(as: FirestoreModels.CategoryBudget.self) else {
                return // No previous data to copy
            }
            
            let previousMonthStart = lastBudget.monthStartDate
            
            // 3. Fetch all budgets from that previous month
            let previousBudgetsSnapshot = try await collection
                .whereField("monthStartDate", isEqualTo: previousMonthStart)
                .getDocuments()
            
            let previousBudgets = previousBudgetsSnapshot.documents.compactMap {
                try? $0.data(as: FirestoreModels.CategoryBudget.self)
            }
            
            // 4. Batch copy them to current month
            let batch = db.batch()
            
            for budget in previousBudgets {
                var newBudget = budget
                newBudget.id = nil // New ID
                newBudget.monthStartDate = currentMonthStart
                newBudget.createdAt = Date()
                
                let ref = collection.document()
                try batch.setData(from: newBudget, forDocument: ref)
            }
            
            try await batch.commit()
            DebugLogger.log("Successfully copied \(previousBudgets.count) budgets to new month")
            
        } catch {
            DebugLogger.log("Error copying budgets: \(error)")
        }
    }
}
