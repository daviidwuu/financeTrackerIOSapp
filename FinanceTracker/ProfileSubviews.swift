import SwiftUI

// MARK: - Account Settings
struct AccountSettingsView: View {
    @State private var name: String = "David Wu"
    @State private var email: String = "david.wu@example.com"
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Profile Information")) {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }
            
            Section(header: Text("Password")) {
                NavigationLink("Change Password") {
                    Text("Change Password Flow")
                        .navigationTitle("Change Password")
                }
            }
            
            Section {
                Button(action: {
                    // Delete account action
                }) {
                    Text("Delete Account")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Account Settings")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Appearance
struct AppearanceSettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Display")) {
                Toggle("Dark Mode", isOn: $isDarkMode)
            }
        }
        .navigationTitle("Appearance")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }
}


// MARK: - Notifications
struct NotificationsSettingsView: View {
    @State private var pushEnabled = true
    @State private var emailEnabled = false
    @State private var promoEnabled = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle("Push Notifications", isOn: $pushEnabled)
                Toggle("Email Notifications", isOn: $emailEnabled)
            }
            
            Section(header: Text("Updates")) {
                Toggle("Promotional Offers", isOn: $promoEnabled)
            }
        }
        .navigationTitle("Notifications")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Privacy & Security
struct PrivacySettingsView: View {
    @State private var faceIDEnabled = true
    @State private var analyticsEnabled = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Security")) {
                Toggle("Use Face ID", isOn: $faceIDEnabled)
                NavigationLink("Two-Factor Authentication") {
                    Text("2FA Setup")
                        .navigationTitle("2FA")
                }
            }
            
            Section(header: Text("Data")) {
                Toggle("Share Analytics", isOn: $analyticsEnabled)
                NavigationLink("Data & Privacy Info") {
                    Text("Privacy Policy Content")
                        .navigationTitle("Privacy Policy")
                }
            }
        }
        .navigationTitle("Privacy & Security")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Help Center
struct HelpCenterView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        List {
            Section(header: Text("FAQ")) {
                NavigationLink("How to add a transaction?") {
                    Text("Tap the + button on the home screen.")
                        .padding()
                        .navigationTitle("Adding Transactions")
                }
                NavigationLink("How to set a budget?") {
                    Text("Go to the Wallet tab and tap + next to Budgets.")
                        .padding()
                        .navigationTitle("Setting Budgets")
                }
                NavigationLink("Exporting data") {
                    Text("Data export is coming soon.")
                        .padding()
                        .navigationTitle("Export Data")
                }
            }
            
            Section(header: Text("Contact")) {
                Button("Contact Support") {
                    // Email support action
                }
                Button("Report a Bug") {
                    // Report bug action
                }
            }
        }
        .navigationTitle("Help Center")
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }
}

// MARK: - About Us
struct AboutView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.doc.horizontal.fill")
                .font(.system(size: 80))
                .foregroundColor(.primary)
                .padding(.top, 40)
            
            VStack(spacing: 8) {
                Text("Finance Tracker")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            List {
                Section {
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("David Wu")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Website")
                        Spacer()
                        Text("example.com")
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color(UIColor.secondarySystemBackground))
                
                Section {
                    Button("Rate App") { }
                    Button("Terms of Service") { }
                    Button("Privacy Policy") { }
                }
                .listRowBackground(Color(UIColor.secondarySystemBackground))
            }
            .scrollContentBackground(.hidden)
        }
        .background(colorScheme == .dark ? Color.black : Color(UIColor.systemGroupedBackground))
        .navigationTitle("About Us")
    }
}
