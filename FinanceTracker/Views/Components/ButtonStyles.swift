import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colorScheme) var colorScheme
    
    var isLoading: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.backgroundPrimary))
                    .padding(.trailing, 8)
            }
            
            configuration.label
                .font(.headline)
                .fontWeight(.bold)
        }
        .foregroundColor(isEnabled ? Color.backgroundPrimary : Color.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            isEnabled 
                ? Color.primary 
                : Color(UIColor.systemGray5)
        )
        .clipShape(Capsule())
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .onChange(of: configuration.isPressed) { _, isPressed in
            if isPressed && isEnabled {
                HapticManager.shared.light()
            }
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(isEnabled ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled {
                    HapticManager.shared.light()
                }
            }
    }
}

struct SmallPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline) // Smaller font
            .fontWeight(.semibold)
            .foregroundColor(isEnabled ? Color.backgroundPrimary : Color.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8) // Reduced padding
            .background(isEnabled ? Color.primary : Color(UIColor.systemGray5))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled {
                    HapticManager.shared.light()
                }
            }
    }
}

struct SmallSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(isEnabled ? .primary : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled {
                    HapticManager.shared.light()
                }
            }
    }
}

// Preview to verify styles
struct ButtonStyles_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Button("Primary Action") {}
                .buttonStyle(PrimaryButtonStyle())
            
            Button("Loading") {}
                .buttonStyle(PrimaryButtonStyle(isLoading: true))
            
            Button("Disabled") {}
                .buttonStyle(PrimaryButtonStyle())
                .disabled(true)
            
            Button("Secondary Action") {}
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
    }
}
