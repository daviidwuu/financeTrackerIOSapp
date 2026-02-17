import SwiftUI

struct FriendSearchView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = FriendRepository() // Local repo for search isolation
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [FriendRepository.UserSearchResult] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by username", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }
                        .overlay(searchOverlay)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(AppRadius.small) // Use AppRadius
                .padding()
                
                // Results or Empty State
                if isSearching {
                    ProgressView()
                        .padding(.top, 20)
                    Spacer()
                } else if !searchResults.isEmpty {
                    List {
                        ForEach(searchResults) { user in
                            HStack(spacing: AppSpacing.element) {
                                ProfileAvatar(
                                    text: String(user.name.prefix(1)),
                                    color: Color.random(seed: user.name),
                                    size: 40
                                )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    addFriend(user: user)
                                }) {
                                    Text("Add")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(Capsule())
                                        .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(.plain) // Ensure row doesn't capture tap
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                } else if !searchText.isEmpty {
                    ContentUnavailableView(
                        "No Users Found",
                        systemImage: "person.slash",
                        description: Text("Try searching for a different username.")
                    )
                    Spacer()
                } else {
                    ContentUnavailableView(
                        "Find Friends",
                        systemImage: "person.badge.magnifyingglass",
                        description: Text("Search for your friends by their username to start splitting bills.")
                    )
                    Spacer()
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        HapticManager.shared.light()
                        dismiss()
                    }
                }
            }
            .onChange(of: searchText) { oldValue, newValue in
                if newValue.isEmpty {
                    searchResults = []
                }
            }
        }
    }
    
    private var searchOverlay: some View {
        HStack {
            Spacer()
            if !searchText.isEmpty {
                Button(action: {
                    HapticManager.shared.light()
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        
        Task {
            do {
                let results = try await repo.searchUsers(username: searchText)
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                print("Search error: \(error)")
                await MainActor.run { isSearching = false }
            }
        }
    }
    
    private func addFriend(user: FriendRepository.UserSearchResult) {
         Task {
             do {
                 HapticManager.shared.light()
                 try await appState.friendRepo.addFriend(
                     currentUserId: appState.currentUserId,
                     currentUserInfo: (username: appState.currentUserUsername, name: appState.userName, email: appState.userEmail),
                     targetUser: user
                 )
                 // Show success feedback/toast?
                 // For now just dismiss or change button state
                 await MainActor.run {
                     HapticManager.shared.success()
                     dismiss()
                 }
             } catch {
                 HapticManager.shared.error()
                 print("Add friend error: \(error)")
             }
         }
    }
}
