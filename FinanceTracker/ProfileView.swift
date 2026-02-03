import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @AppStorage("userTheme") private var userTheme: String = "system"
    @State private var showSetUsername = false
    
    var body: some View {
        NavigationStack {
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
                                if !appState.currentUserUsername.isEmpty {
                                    Text("@\(appState.currentUserUsername)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Button("Set Username") {
                                        showSetUsername = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                                Text(appState.userEmail.isEmpty ? "No Email" : appState.userEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color(UIColor.secondarySystemBackground))
                    
                    Section("Account") {
                        // Manual Nav Link
                        NavigationLink(destination: FriendsListView()) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("Friends")
                            }
                        }
                        NavigationLink(destination: CurrencySettingsView()) {
                             HStack {
                                 Image(systemName: "banknote.fill")
                                     .foregroundColor(.primary)
                                     .frame(width: 24)
                                 Text("Currency Settings")
                             }
                        }
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
                        NavigationLink(destination: LocationSettingsView()) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("Location Settings")
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
                        NavigationLink(destination: GuidesListView()) {
                            HStack {
                                Image(systemName: "book.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("Guides")
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
                            HapticManager.shared.medium()
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
                .navigationDestination(isPresented: $appState.shouldOpenCurrencySettings) {
                    CurrencySettingsView()
                }
                .sheet(isPresented: $showSetUsername) {
                    SetUsernameView()
                }
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
        .preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))
    }
}

#Preview {
    ProfileView()
}
