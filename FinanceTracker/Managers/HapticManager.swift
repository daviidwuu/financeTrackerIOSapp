import SwiftUI
import UIKit

enum HapticFeedbackStyle: String, CaseIterable, Identifiable {
    case none
    case light
    case medium
    case heavy
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .light: return "Light"
        case .medium: return "Medium (Default)"
        case .heavy: return "Heavy"
        }
    }
}

class HapticManager {
    static let shared = HapticManager()
    
    var currentStyle: HapticFeedbackStyle {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: "hapticFeedbackStyle"),
               let style = HapticFeedbackStyle(rawValue: rawValue) {
                return style
            }
            return .medium
        }
    }
    
    private init() {}
    
    // Light impact for subtle feedback (e.g., selection changes)
    func light() {
        guard currentStyle != .none else { return }
        
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        
        switch currentStyle {
        case .light:
            // Downgrade to lightest possible (or use selection)
            style = .light
        case .medium:
            // Default behavior: Upgraded to .medium for better sensitivity
            style = .medium
        case .heavy:
            // Upgrade to heavy
            style = .heavy
        case .none:
            return
        }
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // Medium impact for standard feedback (e.g., button taps)
    func medium() {
        guard currentStyle != .none else { return }
        
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        
        switch currentStyle {
        case .light:
            style = .medium
        case .medium:
            // Default behavior: Upgraded to .heavy
            style = .heavy
        case .heavy:
            style = .heavy
        case .none:
            return
        }
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    // Heavy impact for important actions (e.g., deleting items)
    func heavy() {
        guard currentStyle != .none else { return }
        
        // Always heavy if enabled, maybe add intensity
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred(intensity: 1.0)
    }
    
    // Success notification (e.g., form submission)
    func success() {
        guard currentStyle != .none else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Warning notification (e.g., validation errors)
    func warning() {
        guard currentStyle != .none else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    // Error notification (e.g., failed actions)
    func error() {
        guard currentStyle != .none else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // Selection feedback (e.g., picking from a list)
    func selection() {
        guard currentStyle != .none else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
