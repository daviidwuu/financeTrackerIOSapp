import Foundation
import SwiftUI

struct OnboardingCategory: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var colorHex: String
    var isSelected: Bool = true
    var budgetAmount: Double? = nil
}

struct OnboardingSavingGoal: Identifiable {
    let id = UUID()
    var name: String
    var targetAmount: Double
    var currentAmount: Double = 0
    var targetDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
    var icon: String
    var colorHex: String
    var isSelected: Bool = false
}

