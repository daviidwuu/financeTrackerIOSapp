import SwiftUI

struct CategoryIconView: View {
    let category: String?
    let iconOverride: String?
    let colorOverride: String?
    let type: String? // "settlement", "income", "expense"
    
    @EnvironmentObject var appState: AppState
    
    private var resolvedIcon: String {
        // 1. Check for settlement
        if type == "settlement" {
            return "dollarsign.circle.fill"
        }
        
        // 2. Use override if provided (e.g. from transaction record)
        if let icon = iconOverride, !icon.isEmpty {
            return icon
        }
        
        // 3. Lookup category in Budget/Categories
        if let category = category, !category.isEmpty,
           let budget = appState.budgetRepo.budgets.first(where: { $0.category.lowercased() == category.lowercased() }) {
            return budget.icon
        }
        
        // 4. Fallback based on type
        return type == "income" ? "dollarsign.circle.fill" : "cart.fill"
    }
    
    private var resolvedColor: Color {
        // 1. Check for settlement
        if type == "settlement" {
            return AppColors.functionalIncome
        }
        
        // 2. Use override if provided
        if let hex = colorOverride, !hex.isEmpty {
            return Color(hex: hex)
        }
        
        // 3. Lookup category
        if let category = category, !category.isEmpty,
           let budget = appState.budgetRepo.budgets.first(where: { $0.category.lowercased() == category.lowercased() }) {
            return Color(hex: budget.colorHex)
        }
        
        // 4. Fallback
        return .gray
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(resolvedColor.opacity(0.1))
                .frame(width: 48, height: 48)
            
            Image(systemName: resolvedIcon)
                .font(.system(size: 20))
                .foregroundColor(resolvedColor)
        }
    }
}
