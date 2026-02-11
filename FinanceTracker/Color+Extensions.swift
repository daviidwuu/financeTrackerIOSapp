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
    
    static let systemBackground = Color(UIColor.systemBackground)
    static let secondarySystemBackground = Color(UIColor.secondarySystemBackground)
    static let tertiarySystemBackground = Color(UIColor.tertiarySystemBackground)
    
    static let label = Color(UIColor.label)
    static let secondaryLabel = Color(UIColor.secondaryLabel)
    static let tertiaryLabel = Color(UIColor.tertiaryLabel)
    
    // Semantic Functional Colors
    static let functionalSuccess = Color(hex: "#34C759") // IOS System Green
    static let functionalError = Color(hex: "#FF3B30")   // IOS System Red
    
    // Helper to convert Color to Hex String
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
    
    // Helper to init Color from Hex String
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0
        
        let length = hexSanitized.count
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            self.init(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
            return
        }
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        }
        
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    /// Slightly lighter black for cards in dark mode, off-white for light mode
    static var cardBackground: Color {
        Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(white: 0.1, alpha: 1.0) : UIColor(white: 0.97, alpha: 1.0)
        })
    }
    
    /// Alias for consistent grouped list backgrounds
    static var listBackground: Color {
        Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? .black : UIColor.systemGroupedBackground
        })
    }
    
    static let selectableColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown, .gray
    ]
    
    // MARK: - Premium Gradients
    struct GradientTheme: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let colors: [Color]
        let startPoint: UnitPoint
        let endPoint: UnitPoint
        
        static let ocean = GradientTheme(name: "Ocean", colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let sunset = GradientTheme(name: "Sunset", colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let berry = GradientTheme(name: "Berry", colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let forest = GradientTheme(name: "Forest", colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let midnight = GradientTheme(name: "Midnight", colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let ember = GradientTheme(name: "Ember", colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        static let royal = GradientTheme(name: "Royal", colors: [Color(hex: "4158D0"), Color(hex: "C850C0")], startPoint: .topLeading, endPoint: .bottomTrailing)
        
        static let allThemes: [GradientTheme] = [.ocean, .sunset, .berry, .forest, .midnight, .ember, .royal]
        
        static func from(colorHex: String?) -> GradientTheme {
            guard let hex = colorHex else { return .ocean }
            // If the hex matches a theme's first color, return that theme
            if let match = allThemes.first(where: { $0.colors.first?.toHex() == hex }) {
                return match
            }
            return .ocean 
        }
        
        // Helper to get a gradient from a hex string (store hex as primary color, derive gradient)
        static func gradient(for hex: String?) -> LinearGradient {
            if let hex = hex, let color = Color(hex: hex) as Color? {
                return LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    // Deterministic random color from string seed
    static func random(seed: String) -> Color {
        let total = seed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let index = total % selectableColors.count
        return selectableColors[index]
    }
}
