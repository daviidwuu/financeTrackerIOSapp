import SwiftUI

// MARK: - Redesigned Profile Components

struct ProfileHeaderView: View {
    @ObservedObject var appState: AppState
    var onEditProfile: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(Color.orange) // Brand color
                .frame(width: 86, height: 86)
                .overlay(
                    Text(appState.userName.prefix(1).uppercased())
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            // Text Info
            VStack(spacing: 4) {
                Text(appState.userName.isEmpty ? "User" : appState.userName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(appState.currentUserUsername.isEmpty ? "Set username" : "@\(appState.currentUserUsername)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Edit Button
            Button("Edit profile", action: onEditProfile)
                .buttonStyle(SmallSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct MenuSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content
    
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                    .textCase(.uppercase)
            }
            
            VStack(spacing: 0) {
                content
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(AppRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .padding(.horizontal, AppSpacing.margin)
        .padding(.top, 0) // Reduced top padding
    }
}

struct MenuRowView: View {
    let icon: String?
    let title: String
    let value: String?
    let showChevron: Bool
    @Binding var showToggle: Bool
    private var hasToggle: Bool
    
    init(icon: String? = nil, title: String, value: String? = nil, showChevron: Bool = true, showToggle: Binding<Bool>? = nil) {
        self.icon = icon
        self.title = title
        self.value = value
        self.showChevron = showChevron
        self._showToggle = showToggle ?? Binding.constant(false)
        self.hasToggle = showToggle != nil
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon (if present)
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .frame(width: 24, height: 24)
            }
            
            // Title
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Value or Toggle or Chevron
            if hasToggle {
                Toggle("", isOn: $showToggle)
                    .labelsHidden()
                    .toggleStyle(MonochromaticToggleStyle())
                    .onChange(of: showToggle) { _, _ in
                        HapticManager.shared.light()
                    }
            } else {
                if let value = value {
                    Text(value)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .contentShape(Rectangle()) // Make full row tappable
    }
}

// Custom Divider
struct MenuDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 56) // Align with text start (16 padding + 24 icon + 16 spacing)
    }
}

// Custom Input Row
struct MenuInputRow: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .sentences
    
    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .leading)
            
            TextField(title, text: $text)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboardType)
                .autocapitalization(autocapitalization)
                .disableAutocorrection(true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(UIColor.secondarySystemBackground))
        .contentShape(Rectangle())
    }
}

// MARK: - Custom Toggle Style
struct MonochromaticToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 16)
                    .fill(configuration.isOn ? Color.primary : Color(UIColor.systemGray5))
                    .frame(width: 51, height: 31)
                    .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
                
                // Thumb
                Circle()
                    .fill(configuration.isOn ? Color.backgroundPrimary : .white)
                    .padding(2)
                    .frame(width: 31, height: 31)
                    .offset(x: configuration.isOn ? 10 : -10)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
            }
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}
