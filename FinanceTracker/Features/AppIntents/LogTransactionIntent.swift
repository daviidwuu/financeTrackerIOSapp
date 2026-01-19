import AppIntents
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

struct LogTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Transaction"
    static var description = IntentDescription("Log a new transaction to your Finance Tracker.")
    
    // We want this to run in the background without opening the app if possible
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Amount", requestValueDialog: "How much did you spend?")
    var amount: Double
    
    @Parameter(title: "Category", requestValueDialog: "Which category?")
    var category: TransactionCategoryEntity
    
    @Parameter(title: "Note", requestValueDialog: "Any note?")
    var note: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) for \(\.$category) with \(\.$note)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Ensure user is logged in
        guard let user = Auth.auth().currentUser else {
            throw Error.notLoggedIn
        }
        
        // Ensure category belongs to this user
        guard category.userId == user.uid else {
            throw Error.categoryMismatch
        }
        
        let db = Firestore.firestore()
        
        // Fetch budget document
        let categoryRef = db.collection("users").document(user.uid).collection("budgets").document(category.id)
        let categorySnapshot = try await categoryRef.getDocument()
        
        guard let budgetData = try? categorySnapshot.data(as: FirestoreModels.CategoryBudget.self) else {
            throw Error.categoryNotFound
        }
        
        // Explicitly ask for note if not provided (User requested this behavior)
        let finalNote: String?
        if let n = note {
            finalNote = n
        } else {
            // This forces the prompt to appear
            finalNote = try? await $note.requestValue("Any notes for this transaction?")
        }
        
        // Use budget category name as title, note as description (consistent with AddTransactionView)
        let title = budgetData.category
        
        let newTransaction = FirestoreModels.Transaction(
            id: nil,
            title: title,
            subtitle: budgetData.category,
            amount: (budgetData.type == "income" ? abs(amount) : -abs(amount)),
            date: Date(),
            icon: budgetData.icon,
            colorHex: budgetData.colorHex,
            note: finalNote,
            type: budgetData.type ?? "expense",
            source: "shortcuts",
            userId: user.uid,
            createdAt: Date()
        )
        
        let transactionsCollection = db.collection("users").document(user.uid).collection("transactions")
        try transactionsCollection.document().setData(from: newTransaction)
        
        // Trigger notification immediately
        NotificationManager.shared.sendTransactionNotification(
            amount: abs(amount),
            category: title,
            type: budgetData.type ?? "expense" // Use original budget type logic
        )
        
        return .result(value: "Logged \(amount) for \(category.name)")
    }
    
    enum Error: Swift.Error, CustomLocalizedStringResourceConvertible {
        case notLoggedIn
        case categoryNotFound
        case categoryMismatch
        
        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .notLoggedIn: return "You need to be logged into Finance Tracker."
            case .categoryNotFound: return "Category not found."
            case .categoryMismatch: return "This category belongs to a different user account."
            }
        }
    }
}
