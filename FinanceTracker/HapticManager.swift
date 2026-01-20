import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // Light impact for subtle feedback (e.g., selection changes)
    // Upgraded to .medium for better sensitivity
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // Medium impact for standard feedback (e.g., button taps)
    // Upgraded to .heavy for better sensitivity
    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    // Heavy impact for important actions (e.g., deleting items)
    func heavy() {
        // Already at max impact, but ensuring intensity
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred(intensity: 1.0)
    }
    
    // Success notification (e.g., form submission)
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // Warning notification (e.g., validation errors)
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    // Error notification (e.g., failed actions)
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // Selection feedback (e.g., picking from a list)
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
