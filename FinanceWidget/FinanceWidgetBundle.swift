import WidgetKit
import SwiftUI

@main
struct FinanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        BudgetWidget()
        QuickLogWidget()
        RecentTransactionsWidget()
    }
}
