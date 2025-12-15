import SwiftUI

struct Transaction: Identifiable {
    let id = UUID()
    var title: String
    var subtitle: String
    var amount: String
    var icon: String
    var color: Color
    var date: Date = Date()
    var notes: String = ""
}

struct SavingGoal: Identifiable {
    let id = UUID()
    var name: String
    var currentAmount: Double
    var targetAmount: Double
    var icon: String
    var color: Color = .primary
    var targetDate: Date = Date()
}

struct RecurringTransaction: Identifiable {
    let id = UUID()
    var name: String
    var amount: Double
    var icon: String
    var color: Color
    var frequency: String
    var notes: String = ""
}

struct Budget: Identifiable {
    let id = UUID()
    var category: String
    var remainingAmount: Double
    var totalAmount: Double
    var icon: String
    var color: Color
    var frequency: String
}
