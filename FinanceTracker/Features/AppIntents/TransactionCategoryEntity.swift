import AppIntents
import FirebaseFirestore
import FirebaseAuth

struct TransactionCategoryEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    
    var id: String
    var name: String
    var icon: String
    var userId: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: nil, image: .init(systemName: icon))
    }
    
    static var defaultQuery = TransactionCategoryQuery()
    
    // MARK: - Initializers
    
    init(id: String, name: String, icon: String, userId: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.userId = userId
    }
    
    init(from budget: FirestoreModels.CategoryBudget) {
        self.id = budget.id ?? UUID().uuidString
        self.name = budget.category // Map category name
        self.icon = budget.icon
        self.userId = budget.userId
    }
}

struct TransactionCategoryQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [TransactionCategoryEntity] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }
        let db = Firestore.firestore()
        
        // Fetch specific budgets by IDs
        // Since we are using Budget IDs as identifiers, we can fetch them directly.
        // However, for efficiency with Firestore, we might want to just fetch them individually or use what we have.
        // Given likely small number, fetching all active budgets and filtering is safer for consistency?
        // Or just map.
        
        // To be safe and reuse logic, let's fetch directly.
        // Note: This assumes identifiers are budget IDs.
        
        var entities: [TransactionCategoryEntity] = []
        for id in identifiers {
            let docRef = db.collection("users").document(userId).collection("budgets").document(id)
            if let snapshot = try? await docRef.getDocument(),
               let budget = try? snapshot.data(as: FirestoreModels.CategoryBudget.self) {
                 entities.append(TransactionCategoryEntity(from: budget))
            }
        }
        return entities
    }
    
    @MainActor
    func suggestedEntities() async throws -> [TransactionCategoryEntity] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }
        let db = Firestore.firestore()
        
        // Calculate search window (last 3 months to be safe)
        // This ensures we find categories even if they haven't been rolled over to the strictly current month yet.
        let sixtyDaysAgo = Date().addingTimeInterval(-90 * 24 * 3600)
        
        // We'll fetch by 'createdAt' or 'monthStartDate' to be broad.
        // Let's use 'monthStartDate' >= 3 months ago.
        
        let snapshot = try await db.collection("users").document(userId).collection("budgets")
            .whereField("monthStartDate", isGreaterThanOrEqualTo: sixtyDaysAgo)
            .order(by: "monthStartDate", descending: true) // Get newest first
            .getDocuments()
            
        // Fetch and map documents step-by-step to help type inference
        let documents = snapshot.documents
        let budgets = documents.compactMap { try? $0.data(as: FirestoreModels.CategoryBudget.self) }
        
        let allBudgets = budgets.filter { 
            // Filter optional: The prompt said "only for expenses", usually budgets are expenses but check type if needed
            // AddBudgetView allows "income" type budgets.
            $0.type == "expense" || $0.type == "income" || $0.type == nil 
        }
        
        // Deduplicate: Keep only the latest budget per category (same logic as BudgetRepository)
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
            
        return uniqueBudgets
            .sorted(by: { $0.category < $1.category })
            .map { TransactionCategoryEntity(from: $0) }
    }
}
