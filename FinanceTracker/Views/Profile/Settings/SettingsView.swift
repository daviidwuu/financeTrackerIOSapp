import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @AppStorage("userTheme") private var userTheme: String = "system"
    @AppStorage("hapticFeedbackStyle") private var currentHapticStyle: HapticFeedbackStyle = .medium

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Appearance Section
                    MenuSection("Appearance") {
                        NavigationLink(destination: AppearanceSettingsView()) {
                            MenuRowView(
                                icon: "paintbrush.fill",
                                title: "Theme",
                                value: userTheme.capitalized
                            )
                        }

                        MenuDivider()

                        NavigationLink(destination: ProfileColorSettingsView()) {
                            MenuRowView(
                                icon: "paintpalette.fill",
                                title: "Profile Color",
                                showChevron: true
                            )
                        }
                    }

                    // App Section
                    MenuSection("App") {
                        NavigationLink(destination: CurrencySettingsView()) {
                            MenuRowView(
                                icon: "banknote.fill",
                                title: "Currency",
                                value: CurrencyManager.shared.mainCurrency
                            )
                        }

                        MenuDivider()

                        NavigationLink(destination: NotificationsSettingsView()) {
                            MenuRowView(
                                icon: "bell.fill",
                                title: "Notifications"
                            )
                        }

                        MenuDivider()
                        
                        MenuControlRow(
                            icon: "waveform",
                            title: "Haptic Feedback"
                        ) {
                            Picker("Haptic Style", selection: $currentHapticStyle) {
                                ForEach(HapticFeedbackStyle.allCases, id: \.self) { style in
                                    Text(style.displayName).tag(style)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .tint(.secondary)
                            .onChange(of: currentHapticStyle) { _, newValue in
                                switch newValue {
                                case .light: HapticManager.shared.light()
                                case .medium: HapticManager.shared.medium()
                                case .heavy: HapticManager.shared.heavy()
                                case .none: break
                                }
                            }
                        }
                    }

                    // Privacy & Security Section
                    MenuSection("Privacy & Security") {
                        NavigationLink(destination: AccountSettingsView()) {
                            MenuRowView(
                                icon: "gearshape.fill",
                                title: "Account Settings"
                            )
                        }

                        MenuDivider()

                        NavigationLink(destination: PrivacySettingsView()) {
                            MenuRowView(
                                icon: "lock.fill",
                                title: "Privacy & Security"
                            )
                        }
                    }

                    // Resources Section
                    MenuSection("Resources") {
                        NavigationLink(destination: GuidesListView()) {
                            MenuRowView(
                                icon: "book.fill",
                                title: "Guides"
                            )
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .scrollContentBackground(.hidden)
        }
        .overlayHeader(.navigation(title: "Settings", onBack: { dismiss() }))
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
}
