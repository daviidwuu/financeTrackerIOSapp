import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case pink = "pink"
    case ocean = "ocean"
    case midnight = "midnight"
    case forest = "forest"
    case sunset = "sunset"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        self.rawValue.capitalized
    }
    
    var isPremiumOnly: Bool {
        self != .system
    }
    
    // Convert SwiftUI Color to UIColor for traitCollection usage
    private func toUIColor(_ color: Color) -> UIColor {
        UIColor(color)
    }
    
    var backgroundColorLight: UIColor {
        switch self {
        case .system: return .white
        case .pink: return toUIColor(Color(hex: "#FFEDF4"))
        case .ocean: return toUIColor(Color(hex: "#E0F7FA"))
        case .midnight: return toUIColor(Color(hex: "#E8EAF6"))
        case .forest: return toUIColor(Color(hex: "#E8F5E9"))
        case .sunset: return toUIColor(Color(hex: "#FFF3E0"))
        }
    }
    
    var backgroundColorDark: UIColor {
        switch self {
        case .system: return .black
        case .pink: return toUIColor(Color(hex: "#1A000A"))
        case .ocean: return toUIColor(Color(hex: "#00101A"))
        case .midnight: return toUIColor(Color(hex: "#050714"))
        case .forest: return toUIColor(Color(hex: "#001409"))
        case .sunset: return toUIColor(Color(hex: "#1A0A00"))
        }
    }
    
    // Primary card color (lightest shade)
    var cardColorLight: UIColor {
        switch self {
        case .system: return UIColor(white: 0.97, alpha: 1.0)
        case .pink: return toUIColor(Color(hex: "#FFD4E5"))      // Light pink
        case .ocean: return toUIColor(Color(hex: "#B3E5FC"))     // Light blue
        case .midnight: return toUIColor(Color(hex: "#C5CAE9"))  // Light indigo
        case .forest: return toUIColor(Color(hex: "#C8E6C9"))    // Light green
        case .sunset: return toUIColor(Color(hex: "#FFE0B2"))    // Light orange
        }
    }

    var cardColorDark: UIColor {
        switch self {
        case .system: return UIColor(white: 0.1, alpha: 1.0)
        case .pink: return toUIColor(Color(hex: "#330014"))
        case .ocean: return toUIColor(Color(hex: "#002238"))
        case .midnight: return toUIColor(Color(hex: "#10163B"))
        case .forest: return toUIColor(Color(hex: "#003318"))
        case .sunset: return toUIColor(Color(hex: "#331400"))
        }
    }

    // Secondary card color (medium shade)
    var secondaryCardColorLight: UIColor {
        switch self {
        case .system: return UIColor(white: 0.94, alpha: 1.0)
        case .pink: return toUIColor(Color(hex: "#FFB3D1"))      // Medium pink
        case .ocean: return toUIColor(Color(hex: "#81D4FA"))     // Medium blue
        case .midnight: return toUIColor(Color(hex: "#9FA8DA"))  // Medium indigo
        case .forest: return toUIColor(Color(hex: "#A5D6A7"))    // Medium green
        case .sunset: return toUIColor(Color(hex: "#FFCC80"))    // Medium orange
        }
    }

    var secondaryCardColorDark: UIColor {
        switch self {
        case .system: return UIColor(white: 0.15, alpha: 1.0)
        case .pink: return toUIColor(Color(hex: "#4D001F"))
        case .ocean: return toUIColor(Color(hex: "#003350"))
        case .midnight: return toUIColor(Color(hex: "#1A2055"))
        case .forest: return toUIColor(Color(hex: "#004D26"))
        case .sunset: return toUIColor(Color(hex: "#4D1F00"))
        }
    }

    // Accent color (darkest/most saturated shade for emphasis)
    var accentColorLight: UIColor {
        switch self {
        case .system: return toUIColor(Color.blue)
        case .pink: return toUIColor(Color(hex: "#FF4081"))      // Vibrant pink
        case .ocean: return toUIColor(Color(hex: "#0288D1"))     // Vibrant blue
        case .midnight: return toUIColor(Color(hex: "#3F51B5"))  // Vibrant indigo
        case .forest: return toUIColor(Color(hex: "#388E3C"))    // Vibrant green
        case .sunset: return toUIColor(Color(hex: "#F57C00"))    // Vibrant orange
        }
    }

    var accentColorDark: UIColor {
        switch self {
        case .system: return toUIColor(Color.blue)
        case .pink: return toUIColor(Color(hex: "#FF80AB"))
        case .ocean: return toUIColor(Color(hex: "#29B6F6"))
        case .midnight: return toUIColor(Color(hex: "#7986CB"))
        case .forest: return toUIColor(Color(hex: "#66BB6A"))
        case .sunset: return toUIColor(Color(hex: "#FFB74D"))
        }
    }
    
    var listBackgroundColorLight: UIColor {
        switch self {
        case .system: return UIColor.systemGroupedBackground
        default: return self.backgroundColorLight
        }
    }
    
    var listBackgroundColorDark: UIColor {
        switch self {
        case .system: return .black
        default: return self.backgroundColorDark
        }
    }
    
    static var activeTheme: AppTheme {
        let themeString = UserDefaults.standard.string(forKey: "premiumAppTheme") ?? "system"
        return AppTheme(rawValue: themeString) ?? .system
    }
}
