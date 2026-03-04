import SwiftUI

struct ProfileColorSettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedColor: Color
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Color palette for profile avatars
    private let colorOptions: [(name: String, color: Color, hex: String)] = [
        ("Orange", .orange, "#FF9500"),
        ("Red", .red, "#FF3B30"),
        ("Pink", .pink, "#FF2D55"),
        ("Purple", .purple, "#AF52DE"),
        ("Indigo", .indigo, "#5856D6"),
        ("Blue", .blue, "#007AFF"),
        ("Cyan", .cyan, "#32ADE6"),
        ("Teal", .teal, "#5AC8FA"),
        ("Mint", .mint, "#00C7BE"),
        ("Green", .green, "#34C759"),
        ("Yellow", .yellow, "#FFCC00"),
        ("Brown", .brown, "#A2845E"),
        ("Gray", .gray, "#8E8E93")
    ]

    init() {
        // Initialize selectedColor based on AppState's current avatarColor
        // This will be updated in onAppear, but we need a default for @State initialization
        _selectedColor = State(initialValue: .orange)
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)

                    // Preview Section
                    VStack(spacing: 16) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.margin)

                        VStack(spacing: 12) {
                            // Avatar Preview
                            Circle()
                                .fill(selectedColor)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(appState.userName.prefix(1).uppercased())
                                        .font(.system(size: 44, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                            Text(appState.userName)
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("@\(appState.currentUserUsername)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.cardBackground)
                        .cornerRadius(AppRadius.medium)
                        .padding(.horizontal, AppSpacing.margin)
                    }

                    // Color Selection Section
                    VStack(spacing: 16) {
                        Text("Choose Color")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.margin)

                        // Color Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            ForEach(colorOptions, id: \.name) { option in
                                ColorOptionButton(
                                    name: option.name,
                                    color: option.color,
                                    isSelected: isColorSelected(option.color),
                                    action: {
                                        HapticManager.shared.light()
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedColor = option.color
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                    }

                    // Info Note
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Your profile color will be visible to your friends and in groups.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(AppRadius.medium)
                    .padding(.horizontal, AppSpacing.margin)

                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal, AppSpacing.margin)
                    }

                    // Save Button
                    VStack {
                        Button(action: saveColor) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                            } else {
                                Text("Save Color")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(colorScheme == .dark ? Color.white : Color.black)
                        .clipShape(Capsule())
                        .disabled(isLoading || !hasColorChanged())
                        .opacity((isLoading || !hasColorChanged()) ? 0.6 : 1)
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.bottom, 40)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .overlayHeader(.navigation(title: "Profile Color", onBack: { dismiss() }))
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Set initial color from AppState
            if let hexColor = appState.userAvatarColor,
               let matchingOption = colorOptions.first(where: { $0.hex == hexColor }) {
                selectedColor = matchingOption.color
            } else {
                // Default to orange if no color is set
                selectedColor = .orange
            }
        }
    }

    private func isColorSelected(_ color: Color) -> Bool {
        // Compare colors by finding matching option
        if let selectedOption = colorOptions.first(where: { isSameColor($0.color, selectedColor) }),
           let testOption = colorOptions.first(where: { isSameColor($0.color, color) }) {
            return selectedOption.hex == testOption.hex
        }
        return false
    }

    private func isSameColor(_ color1: Color, _ color2: Color) -> Bool {
        // Helper to compare SwiftUI colors by checking if they're in the same position in our palette
        for option in colorOptions {
            let matches1 = colorMatches(option.color, color1)
            let matches2 = colorMatches(option.color, color2)
            if matches1 && matches2 {
                return true
            }
            if matches1 != matches2 {
                return false
            }
        }
        return false
    }

    private func colorMatches(_ color1: Color, _ color2: Color) -> Bool {
        // Use UIColor comparison for more reliable color matching
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let threshold: CGFloat = 0.01
        return abs(r1 - r2) < threshold && abs(g1 - g2) < threshold && abs(b1 - b2) < threshold
    }

    private func hasColorChanged() -> Bool {
        guard let currentHex = appState.userAvatarColor,
              let currentOption = colorOptions.first(where: { $0.hex == currentHex }),
              let selectedOption = colorOptions.first(where: { isSameColor($0.color, selectedColor) }) else {
            // If no current color, consider it changed if not orange
            let selectedOption = colorOptions.first(where: { isSameColor($0.color, selectedColor) })
            return selectedOption?.hex != "#FF9500" // Orange is default
        }
        return currentOption.hex != selectedOption.hex
    }

    private func saveColor() {
        guard let selectedOption = colorOptions.first(where: { isSameColor($0.color, selectedColor) }) else {
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Update Firestore
                try await FirebaseManager.shared.updateUserProfile(
                    userId: appState.currentUserId,
                    data: ["avatarColor": selectedOption.hex]
                )

                // Update AppState
                await MainActor.run {
                    appState.userAvatarColor = selectedOption.hex
                    isLoading = false
                    HapticManager.shared.success()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save color: \(error.localizedDescription)"
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - Color Option Button

struct ColorOptionButton: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                HapticManager.shared.selection()
                action()
            }) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 60, height: 60)
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)

                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 60, height: 60)

                        Circle()
                            .stroke(color.opacity(0.5), lineWidth: 6)
                            .frame(width: 72, height: 72)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(color)
                                    .frame(width: 28, height: 28)
                            )
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            Text(name)
                .font(.caption2)
                .foregroundColor(isSelected ? .primary : .secondary)
                .fontWeight(isSelected ? .semibold : .regular)
        }
    }
}

#Preview {
    ProfileColorSettingsView()
        .environmentObject(AppState.shared)
}
