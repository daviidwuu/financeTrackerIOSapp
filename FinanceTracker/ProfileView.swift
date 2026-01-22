import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                (colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea()
                
                List {
                    Section {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.primary)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.userName.isEmpty ? "User" : appState.userName)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text(appState.userEmail.isEmpty ? "No Email" : appState.userEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color(UIColor.secondarySystemBackground))
                    
                    Section("Account") {
                        NavigationLink(destination: AccountSettingsView()) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("Account Settings")
                            }
                        }
                        NavigationLink(destination: AppearanceSettingsView()) {
                            HStack {
                                Image(systemName: "paintbrush.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("Appearance")
                            }
                        }
                        NavigationLink(destination: NotificationsSettingsView()) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("Notifications")
                            }
                        }
                        NavigationLink(destination: PrivacySettingsView()) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("Privacy & Security")
                            }
                        }
                    }
                    .listRowBackground(Color(UIColor.secondarySystemBackground))
                    
                    Section("Support") {
                        NavigationLink(destination: ShortcutsView()) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("Apple Shortcuts")
                            }
                        }
                        NavigationLink(destination: HelpCenterView()) {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("Help Center")
                            }
                        }
                        NavigationLink(destination: AboutView()) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("About Us")
                            }
                        }
                    }
                    .listRowBackground(Color(UIColor.secondarySystemBackground))
                    
                    Section {
                        Button(action: {
                            appState.logout()
                        }) {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                        }
                    }
                    .listRowBackground(Color(UIColor.secondarySystemBackground))
                }
                .scrollContentBackground(.hidden)
                .background(colorScheme == .dark ? Color.black : Color.white)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

#Preview {
    ProfileView()
}
