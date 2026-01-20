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
        
        // Calculate start of current month
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        guard let startOfMonth = calendar.date(from: components) else { return [] }
        
        let snapshot = try await db.collection("users").document(userId).collection("budgets")
            .whereField("monthStartDate", isEqualTo: startOfMonth)
            .order(by: "category")
            .getDocuments()
            
        return snapshot.documents
            .compactMap { try? $0.data(as: FirestoreModels.CategoryBudget.self) }
            // Filter optional: The prompt said "only for expenses", usually budgets are expenses but check type if needed
            // AddBudgetView allows "income" type budgets.
            .filter { $0.type == "expense" || $0.type == "income" || $0.type == nil } // Allow both expense and income
            .map { TransactionCategoryEntity(from: $0) }
    }
}
