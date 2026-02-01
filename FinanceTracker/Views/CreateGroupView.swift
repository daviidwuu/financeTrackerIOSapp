import SwiftUI

struct CreateGroupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @StateObject private var friendRepo = FriendRepository()
    @StateObject private var groupRepo = GroupRepository()
    
    @State private var groupName = ""
    @State private var selectedIcon = "person.3.fill"
    @State private var selectedFriendIds: Set<String> = []
    @State private var showIconPicker = false
    
    // Icons suitable for groups
    let groupIcons = [
        "person.3.fill", "house.fill", "airplane", "cart.fill",
        "gift.fill", "fork.knife", "gamecontroller.fill", "bed.double.fill",
        "car.fill", "heart.fill", "star.fill", "bolt.fill"
    ]
    
    var onSave: ((FirestoreModels.Group) -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Group Details")) {
                    TextField("Group Name", text: $groupName)
                    
                    HStack {
                        Text("Icon")
                        Spacer()
                        Button(action: { showIconPicker = true }) {
                            Image(systemName: selectedIcon)
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("Select Members")) {
                    if friendRepo.friends.isEmpty {
                        Text("No friends to add. Add friends first!")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(friendRepo.friends) { friend in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(friend.name)
                                        .font(.body)
                                    Text("@\(friend.username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if let fid = friend.id {
                                    Image(systemName: selectedFriendIds.contains(fid) ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundColor(selectedFriendIds.contains(fid) ? .blue : .gray.opacity(0.3))
                                        .onTapGesture {
                                            toggleSelection(fid)
                                        }
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let fid = friend.id {
                                    toggleSelection(fid)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(groupName.isEmpty || selectedFriendIds.isEmpty)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                NavigationStack {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 20) {
                            ForEach(groupIcons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? .blue : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.1) : Color.clear)
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        selectedIcon = icon
                                        showIconPicker = false
                                    }
                            }
                        }
                        .padding()
                    }
                    .navigationTitle("Select Icon")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                if !appState.currentUserId.isEmpty {
                    friendRepo.startListening(userId: appState.currentUserId)
                    groupRepo.startListening(userId: appState.currentUserId)
                }
            }
        }
    }
    
    private func toggleSelection(_ id: String) {
        if selectedFriendIds.contains(id) {
            selectedFriendIds.remove(id)
        } else {
            selectedFriendIds.insert(id)
        }
    }
    
    private func createGroup() {
        guard !groupName.isEmpty, !selectedFriendIds.isEmpty else { return }
        
        let newGroup = FirestoreModels.Group(
            name: groupName,
            memberIds: Array(selectedFriendIds),
            icon: selectedIcon,
            createdAt: Date()
        )
        
        Task {
            if let id = try? await groupRepo.addGroup(newGroup) {
                var groupWithId = newGroup
                groupWithId.id = id
                
                await MainActor.run {
                    onSave?(groupWithId)
                    dismiss()
                }
            } else {
                 // Fallback if add fails or no ID returned (shouldn't happen with updated repo)
                 dismiss()
            }
        }
    }
}
