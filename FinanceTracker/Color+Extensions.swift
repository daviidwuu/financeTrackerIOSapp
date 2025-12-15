import SwiftUI

extension Color {
    /// True Black for Dark Mode, Pure White for Light Mode
    static var backgroundPrimary: Color {
        Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? .black : .white
        })
    }
    
    /// White for Dark Mode, Black for Light Mode
    static var textPrimary: Color {
        Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? .white : .black
        })
    }
    
    /// Slightly lighter black for cards in dark mode, off-white for light mode
    static var cardBackground: Color {
        Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(white: 0.1, alpha: 1.0) : UIColor(white: 0.97, alpha: 1.0)
        })
    }
}
