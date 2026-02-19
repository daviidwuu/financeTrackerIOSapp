import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @AppStorage("userTheme") private var userTheme: String = "system"
    @AppStorage("hapticFeedbackStyle") private var currentHapticStyle: HapticFeedbackStyle = .medium
    @State private var showSetUsername = false
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background
                (colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Spacer for fixed Navigation Bar
                        Spacer().frame(height: 60)
                        
                        // Scrollable Header Content
                        VStack(spacing: 12) {
                            // Avatar
                            Circle()
                                .fill(Color.orange)
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
                            
                            // Actions (Edit Profile) - Directly to Account Settings
                            NavigationLink(destination: AccountSettingsView()) {
                                Text("Edit profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(colorScheme == .dark ? .black : .white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, AppSpacing.margin)
                                    .background(colorScheme == .dark ? Color.white : Color.black)
                                    .clipShape(Capsule())
                            }
                            
                            .padding(.top, 4)
                        }
                        .padding(.bottom, AppSpacing.section)
                        .padding(.top, 24)
                        
                        VStack(spacing: AppSpacing.section) {
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
                            
                            
                            MenuDivider()
                            
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
                            
                            NavigationLink(destination: HapticSettingsView()) {
                                MenuRowView(
                                    icon: "waveform",
                                    title: "Haptic Feedback",
                                    value: currentHapticStyle.displayName
                                )
                            }
                            
                        }
                        
                        // 5. Security & Privacy
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
                            
                            
                            MenuDivider()
                            
                            NavigationLink(destination: LocationSettingsView()) {
                                MenuRowView(
                                    icon: "location.fill",
                                    title: "Location"
                                )
                            }
                            
                        }
                        
                        // 6. Support
                        MenuSection("Support") {
                            NavigationLink(destination: HelpCenterView()) {
                                MenuRowView(
                                    icon: "questionmark.circle.fill",
                                    title: "Help Center"
                                )
                            }
                            
                            
                            MenuDivider()
                            
                            NavigationLink(destination: GuidesListView()) {
                                MenuRowView(
                                    icon: "book.fill",
                                    title: "Guides"
                                )
                            }
                            
                            
                            MenuDivider()
                            
                            NavigationLink(destination: AboutView()) {
                                MenuRowView(
                                    icon: "info.circle.fill",
                                    title: "About Us"
                                )
                            }
                            
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
                                    .cornerRadius(AppRadius.medium)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.medium)
                                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.bottom, 40)
                    }
                    
                    // Version info footer
                VStack(spacing: 4) {
                    Text("wym for iOS")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Version 1.0.0 (Build 1)")
                        .font(.caption2)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
                .padding(.bottom, 20)
            }
            .padding(.bottom, 40) // Add bottom padding for scroll content
        }
        .scrollContentBackground(.hidden)
        
        // Fixed Navigation Bar
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .frame(width: 44, height: 44)
                    .background((colorScheme == .dark ? Color.white : Color.black).opacity(0.05))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Spacer()
            
            // Placeholder to balance layout
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, AppSpacing.margin + AppSpacing.compact)
        .padding(.top, 16)
    }
}
.sheet(isPresented: $showSetUsername) {
    SetUsernameView()
}
.preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))
}
}

#Preview {
ProfileView()
}
