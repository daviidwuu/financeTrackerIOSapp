import SwiftUI

struct GroupMembersView: View {
    let group: FirestoreModels.Group
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var repo = SocialRepository()
    
    @State private var showingAddMember = false
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                // Custom Header
                ZStack {
                    Text("Group Members")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        Spacer()
                    }
                }
                .padding(AppSpacing.margin)
                .background(Color.backgroundPrimary.opacity(0.95))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Action: Add Member
                        Button(action: { showingAddMember = true }) {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                                        .foregroundColor(.secondary)
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            Image(systemName: "plus")
                                                .font(.headline)
                                                .foregroundColor(.secondary)
                                        )
                                }
                                
                                Text("Add Members")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(AppRadius.medium)
                            .padding(.horizontal, AppSpacing.margin)
                        }
                        
                        // Members List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MEMBERS (\(group.members.count))")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, AppSpacing.margin)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(group.members, id: \.self) { memberId in
                                    MemberRow(
                                        name: resolveName(id: memberId),
                                        isAdmin: memberId == group.createdBy,
                                        isYou: memberId == appState.currentUserId
                                    )
                                    .padding(.horizontal, AppSpacing.margin)
                                }
                            }
                        }
                    }
                    .padding(.top)
                }
            }
        }
        .sheet(isPresented: $showingAddMember) {
            AddGroupMemberView(groupId: group.id ?? "", onAddMembers: addMembers)
                .presentationDetents([.large])
        }
    }
    
    private func resolveName(id: String) -> String {
        if id == appState.currentUserId { return "You" }
        if let friend = appState.friendRepo.friends.first(where: { $0.id == id }) { return friend.name }
        if let guest = appState.guestRepo.guests.first(where: { $0.id == id }) { return guest.name }
        if let denormalizedName = group.memberNames?[id] { return denormalizedName }
        return "Unknown Member"
    }
    
    private func addMembers(friends: [FirestoreModels.Friend], guests: [FirestoreModels.Guest]) {
        guard let groupId = group.id else { return }
        
        var newMembers: [(id: String, name: String)] = []
        
        for friend in friends {
            if let id = friend.id {
                newMembers.append((id: id, name: friend.name))
            }
        }
        
        for guest in guests {
            if let id = guest.id {
                newMembers.append((id: id, name: guest.name))
            }
        }
        
        guard !newMembers.isEmpty else { return }
        
        HapticManager.shared.success()
        Task {
            do {
                try await repo.addMembersToGroup(groupId: groupId, newMembers: newMembers)
            } catch {
                print("Error adding members: \(error)")
                HapticManager.shared.error()
            }
        }
    }
}

struct MemberRow: View {
    let name: String
    let isAdmin: Bool
    let isYou: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ProfileAvatar(
                text: String(name.prefix(1)),
                color: Color.random(seed: name),
                size: 48
            )
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if isYou {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isAdmin {
                    Text("Admin")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
    }
}
