import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    
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
                            Label("Account Settings", systemImage: "gearshape.fill")
                        }
                        NavigationLink(destination: AppearanceSettingsView()) {
                            Label("Appearance", systemImage: "paintbrush.fill")
                        }
                        NavigationLink(destination: NotificationsSettingsView()) {
                            Label("Notifications", systemImage: "bell.fill")
                        }
                        NavigationLink(destination: PrivacySettingsView()) {
                            Label("Privacy & Security", systemImage: "lock.fill")
                        }
                    }
                    .listRowBackground(Color(UIColor.secondarySystemBackground))
                    
                    Section("Support") {
                        NavigationLink(destination: ShortcutsView()) {
                            Label("Apple Shortcuts", systemImage: "bolt.fill")
                        }
                        NavigationLink(destination: HelpCenterView()) {
                            Label("Help Center", systemImage: "questionmark.circle.fill")
                        }
                        NavigationLink(destination: AboutView()) {
                            Label("About Us", systemImage: "info.circle.fill")
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
    }
}

#Preview {
    ProfileView()
}
