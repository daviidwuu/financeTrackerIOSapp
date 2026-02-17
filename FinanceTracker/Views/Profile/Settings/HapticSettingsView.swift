import SwiftUI

struct HapticSettingsView: View {
    @AppStorage("hapticFeedbackStyle") private var currentStyle: HapticFeedbackStyle = .medium
    
    var body: some View {
        Form {
            Section(header: Text("Haptic Feedback Intensity")) {
                Picker("Intensity", selection: $currentStyle) {
                    ForEach(HapticFeedbackStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.inline)
            }
            
            Section(footer: Text("Control the strength of vibrations throughout the app. Heavier settings provide more tactile feedback.")) {
                Button(action: {
                    // Test the feedback
                    // Trigger based on current selection logic
                    // We need to manually trigger because the manager reads the AppStorage, 
                    // which is updated by the picker.
                    switch currentStyle {
                    case .none:
                        break
                    case .light:
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    case .medium:
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    case .heavy:
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.impactOccurred()
                    }
                }) {
                    HStack {
                        Text("Test Feedback")
                        Spacer()
                        Image(systemName: "waveform")
                    }
                }
            }
        }
        .navigationTitle("Haptic Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        HapticSettingsView()
    }
}
