import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @AppStorage("userTheme") private var userTheme: String = "system"
    @State private var showSetUsername = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. ChatGPT-style Header
                    ProfileHeaderView(appState: appState) {
                        showSetUsername = true
                    }
                    .padding(.top, 10)
                    
                    // 2. Account Section
                    MenuSection("Account") {
                        // Email (Static)
                        MenuRowView(
                            icon: "envelope.fill",
                            title: "Email",
                            value: appState.userEmail,
                            showChevron: false
                        )
                        MenuDivider()
                        
                        // Plan (Visual only)
                        MenuRowView(
                            icon: "crown.fill",
                            title: "Subscription",
                            value: "Free Plan",
                            showChevron: false
                        )
                    }
                    

                    
                    // 4. App Settings
                    MenuSection("App Settings") {
                        NavigationLink(destination: AppearanceSettingsView()) {
                            MenuRowView(
                                icon: "paintbrush.fill",
                                title: "Appearance",
                                value: userTheme.capitalized
                            )
                        }
                        .buttonStyle(.plain)
                        
                        MenuDivider()
                        
                        NavigationLink(destination: CurrencySettingsView()) {
                            MenuRowView(
                                icon: "banknote.fill",
                                title: "Currency",
                                value: CurrencyManager.shared.mainCurrency
                            )
                        }
                        .buttonStyle(.plain)
                        
                        MenuDivider()
                        
                        NavigationLink(destination: NotificationsSettingsView()) {
                            MenuRowView(
                                icon: "bell.fill",
                                title: "Notifications"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 5. Security & Privacy
                    MenuSection("Privacy & Security") {
                        NavigationLink(destination: AccountSettingsView()) {
                            MenuRowView(
                                icon: "gearshape.fill",
                                title: "Account Settings"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        MenuDivider()
                        
                        NavigationLink(destination: PrivacySettingsView()) {
                            MenuRowView(
                                icon: "lock.fill",
                                title: "Privacy & Security"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        MenuDivider()
                        
                        NavigationLink(destination: LocationSettingsView()) {
                            MenuRowView(
                                icon: "location.fill",
                                title: "Location"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 6. Support
                    MenuSection("Support") {
                        NavigationLink(destination: HelpCenterView()) {
                            MenuRowView(
                                icon: "questionmark.circle.fill",
                                title: "Help Center"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        MenuDivider()
                        
                        NavigationLink(destination: GuidesListView()) {
                            MenuRowView(
                                icon: "book.fill",
                                title: "Guides"
                            )
                        }
                        .buttonStyle(.plain)
                        
                        MenuDivider()
                        
                        NavigationLink(destination: AboutView()) {
                            MenuRowView(
                                icon: "info.circle.fill",
                                title: "About Us"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 7. Log Out
                    VStack {
                        Button(action: {
                            HapticManager.shared.medium()
                            appState.logout()
                        }) {
                            Text("Log out")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.large)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.large)
                                        .stroke(Color.primary.opacity(0.03), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.bottom, 40)
                    
                    // Version info footer
                    VStack(spacing: 4) {
                        Text("FinanceTracker for iOS")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Version 1.0.0 (Build 1)")
                            .font(.caption2)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color(UIColor.systemBackground)) // Main background
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Settings") // Changed from "Profile" to match "Settings" in screenshots often
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold)) // Standard nav bar weight
                            .foregroundColor(Color(UIColor.label).opacity(0.6)) // Slightly softer than black/white
                            .padding(8) // Touch target padding, but no background
                            .contentShape(Circle()) // Helper for touch area
                    }
                }
            }
            .sheet(isPresented: $showSetUsername) {
                SetUsernameView()
            }
            .navigationDestination(isPresented: $appState.shouldOpenCurrencySettings) {
                CurrencySettingsView()
            }
        }
        .preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))
    }
}

#Preview {
    ProfileView()
}
