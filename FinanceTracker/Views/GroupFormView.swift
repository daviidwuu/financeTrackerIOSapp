import SwiftUI

struct GroupFormView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @StateObject private var friendRepo = FriendRepository()
    
    var groupToEdit: FirestoreModels.Group?
    var onSave: ((FirestoreModels.Group) -> Void)?
    
    // Form State
    @State private var groupName = ""
    @State private var selectedIcon = "person.3.fill"
    @State private var selectedColorHex: String? = nil
    @State private var selectedFriendIds: Set<String> = []
    
    @State private var showIconPicker = false
    
    // Gradient Themes
    let themes = Color.GradientTheme.allThemes
    
    // Icons suitable for groups
    let groupIcons = [
        "person.3.fill", "house.fill", "airplane", "cart.fill",
        "gift.fill", "fork.knife", "gamecontroller.fill", "bed.double.fill",
        "car.fill", "heart.fill", "star.fill", "bolt.fill",
        "briefcase.fill", "graduationcap.fill", "leaf.fill", "flame.fill"
    ]
    
    init(groupToEdit: FirestoreModels.Group? = nil, onSave: ((FirestoreModels.Group) -> Void)? = nil) {
        self.groupToEdit = groupToEdit
        self.onSave = onSave
    }
    
    var currentGradient: LinearGradient {
        Color.GradientTheme.gradient(for: selectedColorHex)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Header / Icon Preview
                    VStack(spacing: 16) {
                        Button(action: { showIconPicker = true }) {
                            ZStack {
                                Circle()
                                    .fill(currentGradient)
                                    .frame(width: 100, height: 100)
                                    .shadow(color: Color(hex: selectedColorHex ?? "").opacity(0.4), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                // Edit Badge
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    )
                                    .shadow(radius: 2)
                                    .offset(x: 35, y: 35)
                            }
                        }
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Color Selection
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(themes, id: \.self) { theme in
                                Circle()
                                    .fill(LinearGradient(colors: theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                            .opacity(selectedColorHex == theme.colors.first?.toHex() ? 1 : 0)
                                    )
                                    .shadow(radius: 2)
                                    .scaleEffect(selectedColorHex == theme.colors.first?.toHex() ? 1.1 : 1.0)
                                    .animation(.spring(), value: selectedColorHex)
                                    .onTapGesture {
                                        selectedColorHex = theme.colors.first?.toHex()
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    
                    // MARK: - Group Name Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GROUP NAME")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        TextField("e.g. Apartment, Trip...", text: $groupName)
                            .font(.title3)
                            .fontWeight(.medium)
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Members Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("MEMBERS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(selectedFriendIds.count) of \(friendRepo.friends.count) selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        
                        if friendRepo.friends.isEmpty {
                             VStack(spacing: 12) {
                                Image(systemName: "person.2.slash")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No friends yet")
                                    .font(.headline)
                                Text("Add friends to your profile first!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 1) {
                                ForEach(friendRepo.friends) { friend in
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(Color.secondary.opacity(0.1))
                                                .frame(width: 40, height: 40)
                                            
                                            Text(String(friend.name.prefix(1)).uppercased())
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(friend.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            Text("@\(friend.username)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        if let fid = friend.id {
                                            Image(systemName: selectedFriendIds.contains(fid) ? "checkmark.circle.fill" : "circle")
                                                .font(.title2)
                                                .foregroundColor(selectedFriendIds.contains(fid) ? .blue : .gray.opacity(0.3))
                                                .contentTransition(.symbolEffect(.replace))
                                        }
                                    }
                                    .padding()
                                    .background(Color.cardBackground)
                                    .onTapGesture {
                                        if let fid = friend.id {
                                            toggleSelection(fid)
                                        }
                                    }
                                    
                                    if friend.id != friendRepo.friends.last?.id {
                                        Divider()
                                            .padding(.leading, 70)
                                    }
                                }
                            }
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
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
                    .fontWeight(.bold)
                    .disabled(groupName.isEmpty || selectedFriendIds.isEmpty)
                }
            }
            // Icon Picker Sheet
            .sheet(isPresented: $showIconPicker) {
                NavigationStack {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 20) {
                            ForEach(groupIcons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? .blue : .primary)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.blue.opacity(0.1) : Color.cardBackground)
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
                }
                
                // Pre-populate if editing
                if let group = groupToEdit {
                    groupName = group.name
                    selectedIcon = group.icon
                    selectedColorHex = group.colorHex
                    selectedFriendIds = Set(group.memberIds)
                    
                    // Fallback color if editing old group
                    if selectedColorHex == nil {
                        selectedColorHex = Color.GradientTheme.ocean.colors.first?.toHex()
                    }
                } else {
                     // Default for new
                     selectedColorHex = Color.GradientTheme.ocean.colors.first?.toHex()
                }
            }
        }
    }
    
    private func toggleSelection(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedFriendIds.contains(id) {
                selectedFriendIds.remove(id)
            } else {
                selectedFriendIds.insert(id)
            }
        }
    }
    
    private func saveGroup() {
        guard !groupName.isEmpty, !selectedFriendIds.isEmpty else { return }
        
        var group = groupToEdit ?? FirestoreModels.Group(
            name: groupName,
            memberIds: Array(selectedFriendIds),
            icon: selectedIcon,
            colorHex: selectedColorHex,
            createdAt: Date()
        )
        
        // Update fields
        group.name = groupName
        group.memberIds = Array(selectedFriendIds)
        group.icon = selectedIcon
        group.colorHex = selectedColorHex
        
        Task {
            if group.id != nil {
                // Update
                try? await appState.groupRepo.updateGroup(group)
                await MainActor.run {
                    onSave?(group)
                    dismiss()
                }
            } else {
                // Create
                if let id = try? await appState.groupRepo.addGroup(group) {
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
