import SwiftUI
import WidgetKit

struct AppearanceSettingsView: View {
    @AppStorage("userTheme") private var userTheme: String = "system"
    @AppStorage("premiumAppTheme") private var premiumAppTheme: String = "system"
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            // Background
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)
                    
                    MenuSection("Display") {
                        MenuControlRow(icon: "circle.lefthalf.filled", iconColor: .themeAccent, title: "Mode") {
                            Picker("Mode", selection: $userTheme) {
                                Text("System").tag("system")
                                Text("Light").tag("light")
                                Text("Dark").tag("dark")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .onChange(of: userTheme) { _, _ in
                                HapticManager.shared.light()
                            }
                        }
                        
                        MenuDivider()
                        
                        MenuControlRow(icon: "paintpalette.fill", iconColor: .blue, title: "Premium Theme") {
                            if appState.isPremiumUser {
                                Picker("Premium Theme", selection: $premiumAppTheme) {
                                    ForEach(AppTheme.allCases) { theme in
                                        Text(theme.displayName).tag(theme.rawValue)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .onChange(of: premiumAppTheme) { _, _ in
                                    HapticManager.shared.light()
                                }
                            } else {
                                NavigationLink(destination: SubscriptionView()) {
                                    HStack(spacing: 4) {
                                        Text("Unlock")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(.yellow)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 0)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
        }
        .overlayHeader(.navigation(title: "Appearance", onBack: { dismiss() }))
        .navigationBarBackButtonHidden(true)
    }
}


// MARK: - Notifications
