import SwiftUI

struct GroupFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @StateObject private var friendRepo = FriendRepository()
    @StateObject private var groupRepo = GroupRepository()
    
    var groupToEdit: FirestoreModels.Group?
    var onSave: ((FirestoreModels.Group) -> Void)?
    
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
    
    init(groupToEdit: FirestoreModels.Group? = nil, onSave: ((FirestoreModels.Group) -> Void)? = nil) {
        self.groupToEdit = groupToEdit
        self.onSave = onSave
    }
    
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
            .navigationTitle(groupToEdit == nil ? "New Group" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGroup()
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
                
                // Pre-populate if editing
                if let group = groupToEdit {
                    groupName = group.name
                    selectedIcon = group.icon
                    selectedFriendIds = Set(group.memberIds)
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
    
    private func saveGroup() {
        guard !groupName.isEmpty, !selectedFriendIds.isEmpty else { return }
        
        var group = groupToEdit ?? FirestoreModels.Group(
            name: groupName,
            memberIds: Array(selectedFriendIds),
            icon: selectedIcon,
            createdAt: Date()
        )
        
        // Update fields
        group.name = groupName
        group.memberIds = Array(selectedFriendIds)
        group.icon = selectedIcon
        
        Task {
            if group.id != nil {
                // Update
                try? await groupRepo.updateGroup(group)
                await MainActor.run {
                    onSave?(group)
                    dismiss()
                }
            } else {
                // Create
                if let id = try? await groupRepo.addGroup(group) {
                    var groupWithId = group
                    groupWithId.id = id
                    await MainActor.run {
                        onSave?(groupWithId)
                        dismiss()
                    }
                } else {
                     dismiss()
                }
            }
        }
    }
}
