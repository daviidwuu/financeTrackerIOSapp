import WidgetKit
import SwiftUI

@main
struct FinanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        LockScreenWidget()
        QuickLogWidget()
        
        if #available(iOS 18.0, *) {
            FinanceWidgetControl()
        }
    }
}
