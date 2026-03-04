import AppIntents
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import CoreLocation


struct LogTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Transaction"
    static var description = IntentDescription("Log a new transaction to your wym.")
    
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
        
        // Use the finalNote as the title, falling back to budget category name (consistent with AddTransactionView)
        let title = finalNote ?? budgetData.category
        
        // Check for Travel Mode
        let defaults = UserDefaults.standard
        let isTravelMode = defaults.bool(forKey: "isTravelModeEnabled")
        let mainCurrency = defaults.string(forKey: "mainCurrency") ?? "SGD"
        let travelCurrency = defaults.string(forKey: "travelCurrency") ?? "USD"
        
        var finalAmount = amount
        var originalAmount: Double? = nil
        var currencyCode: String? = nil
        var exchangeRate: Double? = nil
        let type = budgetData.type ?? "expense"
        
        if isTravelMode && mainCurrency != travelCurrency {
            // Amount input is in Travel Currency
            // Load saved rate
            let key = "savedExchangeRate_\(mainCurrency)_\(travelCurrency)"
            let rate = defaults.double(forKey: key)
            
            if rate > 0 {
                // Convert to Main
                // Rate: 1 Main = X Travel.  So Main = Travel / Rate
                finalAmount = amount / rate
                
                originalAmount = amount
                currencyCode = travelCurrency
                exchangeRate = rate
            }
        }
        
        // Ensure correct sign for expense/income
        // If expense, amount stored is negative. If income, positive.
        // We received absolute amount from user input usually, but let's handle signs carefully.
        let absAmount = abs(finalAmount)
        let signedAmount = (type == "income" ? absAmount : -absAmount)

        var newTransaction = FirestoreModels.TransactionModel(
            id: nil,
            userId: user.uid,
            title: title,
            categoryId: category.id,
            amount: signedAmount,
            date: Date(),
            type: type,
            createdAt: Date(),
            note: nil, // Shortcut input is mapped to title, so note is nil
            source: "shortcuts",
            originalAmount: originalAmount,
            currencyCode: currencyCode,
            exchangeRate: exchangeRate
        )
        
        // Automatic Location Capture (matching AddTransactionView behavior)
        let locationEnabled = UserDefaults.standard.object(forKey: "isLocationEnabled") as? Bool ?? true
        
        if locationEnabled {
            let locStatus = LocationManager.shared.authorizationStatus
            if locStatus == .authorizedWhenInUse || locStatus == .authorizedAlways {
                if let location = LocationManager.shared.currentLocation {
                    newTransaction.latitude = location.coordinate.latitude
                    newTransaction.longitude = location.coordinate.longitude
                }
            }
        }
        
        let transactionsCollection = db.collection("users").document(user.uid).collection("transactions")
        try transactionsCollection.document().setData(from: newTransaction)
        
        // Trigger notification immediately
        NotificationManager.shared.sendTransactionNotification(
            amount: abs(finalAmount),
            category: title,
            type: type,
            originalAmount: originalAmount, // This is set correctly in travel logic
            currencyCode: currencyCode
        )
        
        
        // Gamification: Complete "Speedster" mission
        GamificationManager.shared.completeMission(id: "speedster")
        
        return .result(value: "Logged \(amount) for \(category.name)")
    }
    
    enum Error: Swift.Error, CustomLocalizedStringResourceConvertible {
        case notLoggedIn
        case categoryNotFound
        case categoryMismatch
        
        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .notLoggedIn: return "You need to be logged into wym."
            case .categoryNotFound: return "Category not found."
            case .categoryMismatch: return "This category belongs to a different user account."
            }
        }
    }
}
