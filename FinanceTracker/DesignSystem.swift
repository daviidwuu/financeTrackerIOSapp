import SwiftUI

struct AppRadius {
    static let large: CGFloat = 28
    static let medium: CGFloat = 16
    static let small: CGFloat = 12
    static let button: CGFloat = 25
}

struct AppTypography {
    static func heroRounded(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    
    /// Scale for hero inputs (Add Transaction amount)
    static let heroInput = heroRounded(size: 64)
    
    /// Scale for prominent balances (Dashboard)
    static let prominentBalance = heroRounded(size: 42)
    
    /// Scale for section headings
    static let sectionHeader = heroRounded(size: 28)
    
    /// Scale for username and secondary titles
    static let titleDisplay = heroRounded(size: 34)
}

struct AppSpacing {
    /// Standard horizontal margin for the whole app
    static let margin: CGFloat = 20
    
    /// Spacing between major sections
    static let section: CGFloat = 32
    
    /// Spacing between elements within a section
    static let element: CGFloat = 16
    
    /// Spacing for tight groupings
    static let compact: CGFloat = 8
}

extension View {
    func appCardStyle(radius: CGFloat = AppRadius.medium, color: Color = .cardBackground) -> some View {
        self
            .padding()
            .background(color)
            .cornerRadius(radius)
    }
}
