import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @AppStorage("userTheme") private var userTheme: String = "system"
    @AppStorage("hapticFeedbackStyle") private var currentHapticStyle: HapticFeedbackStyle = .medium
    @State private var showSetUsername = false
    @State private var showEditProfile = false
    @State private var devTapCount = 0
    @State private var showDevSettings = false
    @AppStorage("premiumBadgeType") private var badgeType: PremiumBadgeType = .king
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.backgroundPrimary
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        ScrollOffsetTracker()
                        Spacer().frame(height: 80)
                        
                        // Profile Header
                        VStack(spacing: 12) {
                            // Avatar
                            Circle()
                                .fill(appState.userAvatarColor.map { Color(hex: $0) } ?? Color.orange)
                                .frame(width: 86, height: 86)
                                .overlay(
                                    Text(appState.userName.prefix(1).uppercased())
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                .accessibilityLabel("Profile avatar for \(appState.userName.isEmpty ? "User" : appState.userName)")
                            
                            // Text Info
                            VStack(spacing: 4) {
                                Text(appState.userName.isEmpty ? "User" : appState.userName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                if appState.isPremiumUser {
                                    PremiumBadge(size: .small)
                                        .padding(.top, 2)
                                }
                                
                                Text(appState.currentUserUsername.isEmpty ? "Set username" : "@\(appState.currentUserUsername)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.top, appState.isPremiumUser ? 2 : 0)
                            }
                            
                            // Edit Profile Button
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
                        
                        // Subscription Section
                        MenuSection("Subscription") {

                            // Subscription
                            NavigationLink(destination: SubscriptionView()) {
                                MenuRowView(
                                    icon: "crown.fill",
                                    title: "Subscription",
                                    value: appState.isPremiumUser ? "King" : "Free Plan",
                                    showChevron: true
                                )
                            }

                            if appState.isPremiumUser {
                                MenuDivider()

                                NavigationLink(destination: PremiumBadgeSettingsView()) {
                                    MenuRowView(
                                        icon: "star.fill",
                                        title: "Badge Prefix",
                                        value: badgeType.title.capitalized
                                    )
                                }
                            }
                        }

                        // Travel Mode Toggle
                        TravelModeRow()

                        // Preferences
                        MenuSection("Preferences") {
                            NavigationLink(destination: AppearanceSettingsView()) {
                                MenuRowView(
                                    icon: "paintbrush.fill",
                                    title: "Appearance",
                                    value: userTheme.capitalized
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

                            NavigationLink(destination: LocationSettingsView()) {
                                MenuRowView(
                                    icon: "location.fill",
                                    title: "Location"
                                )
                            }

                            MenuDivider()

                            NavigationLink(destination: ShortcutsView()) {
                                MenuRowView(
                                    icon: "bolt.fill",
                                    title: "Shortcuts"
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

                            MenuDivider()

                            NavigationLink(destination: PrivacySettingsView()) {
                                MenuRowView(
                                    icon: "lock.fill",
                                    title: "Privacy & Security"
                                )
                            }
                        }

                        // Support & About
                        MenuSection("Support & About") {
                            NavigationLink(destination: HelpCenterView()) {
                                MenuRowView(
                                    icon: "questionmark.circle.fill",
                                    title: "Support & About"
                                )
                            }
                        }
                        
                        // Log Out
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
                                    .background(Color.cardBackground)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.bottom, 40)
                        
                        // Version info footer
                        VStack(spacing: 4) {
                            Text("wym for iOS")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(AppConfig.versionDisplayString)
                                .font(.caption2)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                                .onTapGesture { HapticManager.shared.light(); 
                                    devTapCount += 1
                                    if devTapCount >= 5 {
                                        devTapCount = 0
                                        showDevSettings = true
                                        HapticManager.shared.success()
                                    }
                                }
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.bottom, 40)
                }
                .scrollContentBackground(.hidden)
            }
            .overlayHeader(.navigation(title: "Settings", onBack: { dismiss() }, backIcon: "xmark"))
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $showDevSettings) {
                DeveloperSettingsView()
            }
            .sheet(isPresented: $showSetUsername) {
                SetUsernameView()
            }
            .preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))
        }
    }
}

// MARK: - Travel Mode Row Component

struct TravelModeRow: View {
    @ObservedObject private var currencyManager = CurrencyManager.shared
    @State private var showCurrencySettings = false

    private var subtitle: String {
        if currencyManager.isTravelModeEnabled {
            return "\(currencyManager.travelCurrency) → \(currencyManager.mainCurrency) @ \(String(format: "%.2f", currencyManager.exchangeRate))"
        } else {
            return "Tap to manage currencies"
        }
    }

    var body: some View {
        MenuSection("Travel") {
            Button(action: {
                HapticManager.shared.light()
                showCurrencySettings = true
            }) {
                HStack(spacing: 16) {
                    // Icon
                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.activeTheme == .system ? Color.primary : Color.themeAccent)
                        .frame(width: 28, height: 28)

                    // Content
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Travel Mode")
                            .font(.body)
                            .foregroundColor(.primary)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Toggle
                    Toggle("", isOn: Binding(
                        get: { currencyManager.isTravelModeEnabled },
                        set: { newValue in
                            HapticManager.shared.light()
                            currencyManager.isTravelModeEnabled = newValue
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(MonochromaticToggleStyle())
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCurrencySettings) {
            CurrencySettingsView()
        }
    }
}

#Preview {
ProfileView()
}
