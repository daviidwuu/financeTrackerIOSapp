import SwiftUI

// MARK: - Form Data Transfer Objects
// These types are used exclusively as intermediary DTOs between Add/Edit sheets
// and the calling views. They are NOT persisted — see FirestoreModels.swift for
// the Codable Firestore types.

struct TransactionFormData: Identifiable {
    let id = UUID()
    var title: String
    var categoryId: String?
    var amount: String
    var date: Date = Date()
    var notes: String = ""
    var type: String = "expense"
    
    // Currency Support
    var currencyCode: String?
    var exchangeRate: Double?
    var originalAmount: Double?
    
    // Location
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
}

struct SavingGoalFormData: Identifiable {
    let id = UUID()
    var name: String
    var currentAmount: Double
    var targetAmount: Double
    var icon: String
    var color: Color = .primary
    var targetDate: Date = Date()
}

struct RecurringTransactionFormData: Identifiable {
    let id = UUID()
    var name: String
    var amount: Double
    var categoryId: String? // Links to CategoryBudget.id
    var icon: String
    var color: Color
    var frequency: String
    var startDate: Date = Date()
    var notes: String = ""
    var type: String = "expense"
}

struct BudgetFormData: Identifiable {
    let id = UUID()
    var category: String
    var remainingAmount: Double
    var totalAmount: Double
    var icon: String
    var color: Color
    var frequency: String
    var type: String = "expense"
}

extension TransactionFormData {
    func firestoreModel(userId: String, source: String? = nil, createdAt: Date = Date()) -> FirestoreModels.TransactionModel {
        FirestoreModels.TransactionModel(
            userId: userId,
            title: title,
            categoryId: categoryId,
            amount: CurrencyInput.parseOrZero(amount),
            date: date,
            type: type,
            createdAt: createdAt,
            note: notes,
            source: source,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            originalAmount: originalAmount,
            currencyCode: currencyCode,
            exchangeRate: exchangeRate
        )
    }
}
