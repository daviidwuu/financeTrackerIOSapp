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
        .foregroundColor(isEnabled ? (AppTheme.activeTheme == .system ? Color.backgroundPrimary : .white) : Color.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            isEnabled
                ? (AppTheme.activeTheme == .system ? Color.textPrimary : Color.themeAccent)
                : Color.secondaryCardBackground
        )
        .clipShape(Capsule())
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .onChange(of: configuration.isPressed) { _, isPressed in
            if isPressed && isEnabled {
                HapticManager.shared.medium()
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
            .background(Color.secondaryCardBackground)
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
            .foregroundColor(isEnabled ? (AppTheme.activeTheme == .system ? Color.backgroundPrimary : .white) : Color.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8) // Reduced padding
            .background(isEnabled ? (AppTheme.activeTheme == .system ? Color.textPrimary : Color.themeAccent) : Color.secondaryCardBackground)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled {
                    HapticManager.shared.medium()
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
            .background(Color.secondaryCardBackground)
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
            Button("Primary Action") { HapticManager.shared.light(); }
                .buttonStyle(PrimaryButtonStyle())
            
            Button("Loading") { HapticManager.shared.light(); }
                .buttonStyle(PrimaryButtonStyle(isLoading: true))
            
            Button("Disabled") { HapticManager.shared.light(); }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(true)
            
            Button("Secondary Action") { HapticManager.shared.light(); }
                .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
    }
}
