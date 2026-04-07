import SwiftUI
import FirebaseFirestore

enum NotificationWrapper: Identifiable {
    case friendRequest(FirestoreModels.FriendRequest)
    case groupDeletion(FirestoreModels.Group)
    case splitRequest(FirestoreModels.SplitRequest)

    var id: String {
        switch self {
        case .friendRequest(let req): return "fr_\(req.id ?? UUID().uuidString)"
        case .groupDeletion(let grp): return "gd_\(grp.id ?? UUID().uuidString)"
        case .splitRequest(let req): return "sr_\(req.id ?? UUID().uuidString)"
        }
    }

    var date: Date {
        switch self {
        case .friendRequest(let req): return req.createdAt
        case .groupDeletion(let grp): return grp.updatedAt ?? grp.createdAt
        case .splitRequest(let req): return req.createdAt
        }
    }
}

struct NotificationCenterView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var requestRepo: RequestRepository
    @EnvironmentObject var friendRequestRepo: FriendRequestRepository
    
    @State private var groupForDeletionAction: FirestoreModels.Group?
    @State private var pendingDeletedGroupIds: Set<String> = []
    
    @State private var selectedRequest: FirestoreModels.SplitRequest?
    @State private var requestToAccept: FirestoreModels.SplitRequest?
    @State private var errorState = ErrorState()

    var allNotifications: [NotificationWrapper] {
        var items: [NotificationWrapper] = []
        
        for req in friendRequestRepo.incomingRequests {
            items.append(.friendRequest(req))
        }
        
        let pendingDeletionGroups = appState.groupRepo.groups.filter { 
            $0.deletionStatus == "requested" && 
            $0.memberActions?[appState.currentUserId] == "pending" &&
            !pendingDeletedGroupIds.contains($0.id ?? "")
        }
        for grp in pendingDeletionGroups {
            items.append(.groupDeletion(grp))
        }
        
        for req in requestRepo.incomingActionableRequests {
            items.append(.splitRequest(req))
        }
        
        return items
    }
    
    var groupedNotifications: [(String, [NotificationWrapper])] {
        let items = allNotifications
        let calendar = Calendar.current
        var groups: [String: [NotificationWrapper]] = [:]
        
        for item in items {
            if calendar.isDateInToday(item.date) {
                groups["Today", default: []].append(item)
            } else if calendar.isDateInYesterday(item.date) {
                groups["Yesterday", default: []].append(item)
            } else if item.date > calendar.date(byAdding: .day, value: -7, to: Date())! {
                groups["This Week", default: []].append(item)
            } else {
                groups["Older", default: []].append(item)
            }
        }
        
        let order = ["Today", "Yesterday", "This Week", "Older"]
        var result: [(String, [NotificationWrapper])] = []
        for key in order {
            if let sectionItems = groups[key], !sectionItems.isEmpty {
                let sortedItems = sectionItems.sorted { $0.date > $1.date }
                result.append((key, sortedItems))
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header — matches AddTransactionView / ModalHeader style
                HStack {
                    Button(action: {
                        HapticManager.shared.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("Notification Centre")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Spacer()

                    // Invisible spacer to keep title centred
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, 16)
                .padding(.bottom, AppSpacing.element)
                .background(Color.backgroundPrimary)

                // Content
                if allNotifications.isEmpty {
                    Spacer()
                    EmptyStateView(
                        icon: "bell.slash",
                        title: "No notifications",
                        message: "You're all caught up! No actions needed at this time.",
                        actionTitle: "",
                        action: {}
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(groupedNotifications, id: \.0) { section in
                            Section(header: Text(section.0).font(.headline).foregroundColor(.secondary)) {
                                ForEach(section.1) { wrapper in
                                    switch wrapper {
                                    case .friendRequest(let req):
                                        FriendRequestCard(request: req)
                                            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(Color.clear)
                                            .padding(.bottom, AppSpacing.compact)
                                    case .groupDeletion(let group):
                                        groupDeletionCard(group)
                                    case .splitRequest(let req):
                                        RequestCardView(
                                            request: req,
                                            onAction: { action in
                                                handleRequestAction(action, for: req)
                                            }
                                        )
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            HapticManager.shared.light()
                                            selectedRequest = req
                                        }
                                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .padding(.bottom, AppSpacing.compact)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                }
            }
        }
        .sheet(item: $selectedRequest) { request in
            SplitRequestDetailView(request: request)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $requestToAccept) { request in
            AddTransactionView(requestToAccept: request, onSave: { transaction in
                 acceptRequest(request, transaction: transaction)
            })
        }
        .alert("Group Deleted: Action Required", isPresented: Binding(
            get: { groupForDeletionAction != nil },
            set: { _ in groupForDeletionAction = nil }
        )) {
            Button("Keep Transaction History") { HapticManager.shared.light()
                if let group = groupForDeletionAction {
                    if let id = group.id {
                        pendingDeletedGroupIds.insert(id)
                    }
                    Task {
                        do {
                            try await appState.groupRepo.submitDeletionAction(group: group, action: "keep")
                        } catch { }
                    }
                }
            }
            Button("Delete All History", role: .destructive) { HapticManager.shared.light()
                if let group = groupForDeletionAction {
                    if let id = group.id {
                        pendingDeletedGroupIds.insert(id)
                    }
                    Task {
                        do {
                            try await appState.groupRepo.submitDeletionAction(group: group, action: "delete")
                        } catch { }
                    }
                }
            }
            Button("Cancel", role: .cancel) { HapticManager.shared.light() }
        } message: {
            if let group = groupForDeletionAction {
                Text("\(group.name) has been deleted by the creator. What would you like to do with your transaction history?")
            }
        }
        .errorBanner(errorState)
    }
    
    @ViewBuilder
    private func groupDeletionCard(_ group: FirestoreModels.Group) -> some View {
        HStack(spacing: AppSpacing.compact) {
            ZStack {
                Circle()
                    .fill(AppColors.functionalExpense.opacity(0.1))
                    .frame(width: AppSize.avatarList, height: AppSize.avatarList)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color.functionalError)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text("Group deletion requested")
                    .font(.caption)
                    .foregroundColor(Color.functionalError)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(AppSpacing.element)
        .background(Color.secondaryCardBackground)
        .cornerRadius(AppRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .stroke(AppColors.functionalExpense.opacity(0.5), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { 
            HapticManager.shared.light(); 
            groupForDeletionAction = group
        }
        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .padding(.bottom, AppSpacing.compact)
    }

    // MARK: - Handlers
    
    private func acceptSettlement(_ request: FirestoreModels.SplitRequest) {
        HapticManager.shared.success()
        Task {
            do {
                try await SocialTransactionManager.shared.acceptSettlement(request: request, currentUserId: appState.currentUserId, currentUserName: appState.userName)
            } catch {
                await MainActor.run { HapticManager.shared.error() }
            }
        }
    }
    
    private func declineSettlement(_ request: FirestoreModels.SplitRequest) {
        HapticManager.shared.heavy()
        Task {
            do {
                try await SocialTransactionManager.shared.declineSettlement(request: request)
            } catch {
                await MainActor.run { HapticManager.shared.error() }
            }
        }
    }
    
    private func acceptRequest(_ request: FirestoreModels.SplitRequest, transaction: TransactionFormData) {
        Task {
            do {
                let acceptedTransaction = transaction.firestoreModel(userId: appState.currentUserId)
                _ = try await SocialTransactionManager.shared.acceptSplitRequest(
                    request: request,
                    acceptedTransaction: acceptedTransaction,
                    currentUserId: appState.currentUserId
                )

                NotificationManager.shared.sendTransactionNotification(
                    amount: acceptedTransaction.amount,
                    category: transaction.title,
                    type: transaction.type,
                    originalAmount: transaction.originalAmount,
                    currencyCode: transaction.currencyCode
                )
            } catch {
                DebugLogger.log("Failed to accept request: \(error)")
                errorState.show("Failed to accept request")
            }
        }
    }
    
    private func declineRequest(_ request: FirestoreModels.SplitRequest) {
        Task {
            do {
                guard let id = request.id else { return }
                try await requestRepo.updateRequestStatus(userId: appState.currentUserId, requestId: id, status: .declined, lastUpdatedBy: appState.currentUserId)
            } catch {
                DebugLogger.log("Failed to decline request: \(error)")
                errorState.show("Failed to decline request")
            }
        }
    }

    private func handleRequestAction(_ action: RequestAction, for request: FirestoreModels.SplitRequest) {
        switch action {
        case .acceptSplit:
            requestToAccept = request
        case .declineSplit:
            declineRequest(request)
        case .acceptSettlement:
            acceptSettlement(request)
        case .declineSettlement:
            declineSettlement(request)
        case .confirmPaymentReceived, .cancelRequest, .resendRequest, .nudge:
            break
        }
    }
}
