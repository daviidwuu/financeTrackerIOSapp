import SwiftUI
import FirebaseFirestore

struct FriendDetailView: View {
    let friend: FirestoreModels.Friend

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var repo = SocialRepository()
    @StateObject private var viewModel = FriendDetailViewModel()

    enum FriendSheet: Identifiable, Equatable {
        case addExpense
        case settleUp
        case transactionDetail(FirestoreModels.TransactionModel)
        case allPendingRequests // [NEW] Navigation to all pending requests

        var id: String {
            switch self {
            case .addExpense: return "addExpense"
            case .settleUp: return "settleUp"
            case .transactionDetail(let tx): return "tx-\(tx.id ?? "")"
            case .allPendingRequests: return "allPendingRequests"
            }
        }

        static func == (lhs: FriendSheet, rhs: FriendSheet) -> Bool { lhs.id == rhs.id }
    }

    @State private var activeSheet: FriendSheet?
    @State private var transactionToEdit: FirestoreModels.TransactionModel?
    @State private var requestToAccept: FirestoreModels.SplitRequest?

    // MARK: - Derived State

    private var visibleRequests: [FirestoreModels.SplitRequest] {
        viewModel.visibleRequests(from: repo.friendTransactions, currentUserId: appState.currentUserId, friend: friend)
    }

    private var incomingActionRequiredRequests: [FirestoreModels.SplitRequest] {
        viewModel.incomingActionRequired(from: visibleRequests, currentUserId: appState.currentUserId, friendName: friend.name)
    }

    private var outgoingOutstandingRequests: [FirestoreModels.SplitRequest] {
        viewModel.outgoingOutstanding(from: visibleRequests, currentUserId: appState.currentUserId, friendName: friend.name)
    }

    // [NEW] Combined array sorted by latest
    private var allPendingRequests: [FirestoreModels.SplitRequest] {
        let all = incomingActionRequiredRequests + outgoingOutstandingRequests
        return all.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.backgroundPrimary.edgesIgnoringSafeArea(.all)

            List {
                headerSection
                pendingRequestsSection
                overviewSection
                recentActivitySection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)

            if viewModel.showUndoToast {
                UndoToast(text: "Status updated", onUndo: { undoToggle() })
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .onAppear { loadData() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addExpense:
                EditGroupTransactionWizardView(group: nil, preSelectedFriend: friend, transactionToEdit: nil) { amount, note, category, splits, originalAmount, currencyCode, exchangeRate in
                    viewModel.handleAddExpense(
                        amount: amount, note: note, category: category, splits: splits,
                        originalAmount: originalAmount, currencyCode: currencyCode, exchangeRate: exchangeRate,
                        currentUserId: appState.currentUserId, userName: appState.userName,
                        friendCache: appState.friendRepo.friends, groupCache: appState.groupRepo.groups,
                        onComplete: { loadData() }
                    )
                }
                .presentationDetents([.large])
            case .settleUp:
                SettleUpWizardView(group: nil, preSelectedFriend: friend)
                    .presentationDetents([.large])
            case .transactionDetail(let tx):
                if let req = viewModel.reconstructRequest(from: tx, currentUserId: appState.currentUserId, friend: friend) {
                    SplitRequestDetailView(request: req)
                        .presentationDetents([.medium, .large])
                } else {
                    Text("Error loading details")
                }
            case .allPendingRequests:
                PendingRequestsListSheet(
                    incomingRequests: incomingActionRequiredRequests,
                    outgoingRequests: outgoingOutstandingRequests,
                    counterpartyName: friend.name,
                    onAction: { action, split in
                        viewModel.handleSplitCardAction(
                            action, split: split,
                            currentUserId: appState.currentUserId, currentUserName: appState.userName,
                            friendTransactions: repo.friendTransactions,
                            onLoadData: loadData,
                            onRequestToAccept: { requestToAccept = $0 }
                        )
                    },
                    onCardTap: { split in
                        if let tx = repo.friendTransactions.first(where: { $0.id == split.id }) {
                            activeSheet = .transactionDetail(tx)
                        }
                    }
                )
            }
        }
        .sheet(item: $transactionToEdit) { tx in
            let groupTx = FirestoreModels.GroupTransaction(
                id: nil,
                title: tx.title,
                amount: tx.amount,
                payerId: tx.userId,
                payerName: appState.userName,
                receiverId: nil,
                receiverName: nil,
                date: tx.date,
                type: tx.type,
                currencyCode: nil,
                note: tx.note,
                originalTransactionId: tx.id,
                originalAmount: nil,
                exchangeRate: nil,
                editHistory: nil
            )
            EditGroupTransactionWizardView(group: nil, preSelectedFriend: friend, transactionToEdit: groupTx) { amount, note, category, splits, originalAmount, currencyCode, exchangeRate in
                viewModel.handleUpdateTransaction(
                    originalTx: tx, amount: amount, note: note, category: category, splits: splits,
                    originalAmount: originalAmount, currencyCode: currencyCode, exchangeRate: exchangeRate,
                    currentUserId: appState.currentUserId, userName: appState.userName,
                    friendCache: appState.friendRepo.friends, groupCache: appState.groupRepo.groups,
                    budgetRepo: appState.budgetRepo,
                    onComplete: { transactionToEdit = nil; loadData() }
                )
            }
            .presentationDetents([.large])
        }
        .sheet(item: $requestToAccept) { request in
            AddTransactionView(requestToAccept: request, onSave: { transaction in
                viewModel.acceptRequest(request, transaction: transaction, currentUserId: appState.currentUserId) {
                    requestToAccept = nil
                    loadData()
                }
            })
        }
        .onChange(of: activeSheet) { _, newValue in
            if newValue == nil { loadData() }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        SocialDetailHeaderSection(
            title: friend.name,
            onBack: { dismiss() },
            avatar: {
                ProfileAvatar(
                    text: String(friend.name.prefix(1)),
                    color: friend.avatarColor.map { Color(hex: $0) } ?? Color.random(seed: friend.name),
                    size: AppSize.avatarHero
                )
            },
            subtitle: {
                SocialHeaderPill { Text("@\(friend.username ?? "")") }
            },
            onSettle: { activeSheet = .settleUp },
            onAddExpense: { activeSheet = .addExpense }
        )
    }

    @ViewBuilder
    private var pendingRequestsSection: some View {
        if let mostRecentSplit = allPendingRequests.first {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill").foregroundColor(.orange)
                        Text("Pending Requests").font(.headline)
                        Spacer()
                        if allPendingRequests.count > 1 {
                            Text("1 of \(allPendingRequests.count)")
                                .font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(spacing: 12) {
                        let presentation = mostRecentSplit.presentation(for: appState.currentUserId, counterpartyName: friend.name)
                        PendingSplitCard(
                            split: mostRecentSplit,
                            userId: appState.currentUserId,
                            presentation: presentation,
                            onAction: { action in
                                viewModel.handleSplitCardAction(
                                    action, split: mostRecentSplit,
                                    currentUserId: appState.currentUserId, currentUserName: appState.userName,
                                    friendTransactions: repo.friendTransactions,
                                    onLoadData: loadData,
                                    onRequestToAccept: { requestToAccept = $0 }
                                )
                            }
                        )
                        .onTapGesture {
                            HapticManager.shared.light()
                            activeSheet = .allPendingRequests
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Overview").font(.headline)
                let balance = repo.friendBalances.values.reduce(0, +)
                let totalSharedText = viewModel.formatCurrencyBreakdown(
                    viewModel.totalSharedByCurrency(transactions: repo.friendTransactions)
                )
                SocialTwoCardRow(
                    left: SocialStatCard(title: "Total Shared", value: totalSharedText),
                    right: SocialStatCard(
                        title: balance >= 0 ? "Owed to You" : "You Owe",
                        value: String(format: "$%.2f", abs(balance)),
                        valueColor: balance == 0 ? .primary : (balance > 0 ? .green : .red)
                    )
                )
            }
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 0, trailing: AppSpacing.margin))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var recentActivitySection: some View {
        Section(header:
            Text("Recent Activity").font(.headline).padding(.vertical, 8)
        ) {
            if repo.isLoading && repo.friendTransactions.isEmpty {
                ProgressView().padding()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if repo.friendTransactions.isEmpty {
                ContentUnavailableView("No activity", systemImage: "clock.arrow.circlepath", description: Text("Shared expenses will appear here."))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(repo.friendTransactions) { transaction in
                    let request = viewModel.reconstructRequest(from: transaction, currentUserId: appState.currentUserId, friend: friend)
                    let canTogglePayment = request?.canCurrentUserConfirmPaymentReceived(currentUserId: appState.currentUserId) == true
                        || request?.canCurrentUserUndoPaymentReceived(currentUserId: appState.currentUserId) == true

                    FriendCardRow(transaction: transaction, friendName: friend.name, friendAvatarColor: friend.avatarColor)
                        .background(Color.cardBackground)
                        .cornerRadius(AppRadius.medium)
                        .onTapGesture { HapticManager.shared.light(); activeSheet = .transactionDetail(transaction) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                HapticManager.shared.light()
                                viewModel.deleteTransaction(transaction, repo: repo, onLoadData: loadData)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)

                            if canTogglePayment {
                                let isPaid = request?.status == .paid
                                Button {
                                    HapticManager.shared.light()
                                    viewModel.toggleTransactionStatus(
                                        transaction,
                                        currentUserId: appState.currentUserId,
                                        currentUserName: appState.userName,
                                        friend: friend,
                                        onLoadData: loadData
                                    )
                                } label: {
                                    Label(isPaid ? "Undo Paid" : "Confirm Paid",
                                          systemImage: isPaid ? "arrow.uturn.backward" : "checkmark.circle")
                                }
                                .tint(isPaid ? .orange : .green)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if transaction.userId == appState.currentUserId && transaction.type != "income" {
                                Button { HapticManager.shared.light(); transactionToEdit = transaction } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: AppSpacing.margin, bottom: 8, trailing: AppSpacing.margin))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                NativeAdView()
                    .listRowInsets(EdgeInsets(top: AppSpacing.compact, leading: AppSpacing.margin, bottom: AppSpacing.compact, trailing: AppSpacing.margin))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .headerProminence(.increased)
    }

    // MARK: - Helpers

    private func loadData() {
        viewModel.loadData(friendId: friend.id, currentUserId: appState.currentUserId, repo: repo)
    }

    private func undoToggle() {
        viewModel.undoToggle(
            currentUserId: appState.currentUserId,
            currentUserName: appState.userName,
            friend: friend,
            onLoadData: loadData
        )
    }
}

// MARK: - FriendCardRow

struct FriendCardRow: View {
    let transaction: FirestoreModels.TransactionModel
    let friendName: String
    let friendAvatarColor: String?

    @EnvironmentObject var appState: AppState

    var body: some View {
        let isYouPaid = transaction.type == "income"
        let totalAmount = transaction.originalAmount

        let subtitle: String
        if let total = totalAmount {
            let formattedTotal = String(format: "$%.2f", total)
            subtitle = isYouPaid ? "You paid \(formattedTotal)" : "\(friendName) paid \(formattedTotal)"
        } else {
            let shareAmount = abs(transaction.amount)
            let formattedShare = String(format: "$%.2f", shareAmount)
            subtitle = isYouPaid ? "You lent \(formattedShare)" : "\(friendName) lent you \(formattedShare)"
        }

        let statusBadge: String? = reconstructedRequest?.presentation(
            for: appState.currentUserId,
            counterpartyName: friendName
        ).badge

        let amountColor: Color = transaction.type == "income" ? .green : .red
        let isSettlement = transaction.categoryId == "settlement"
        let payerDisplayName = isYouPaid ? (appState.userName.isEmpty ? "You" : appState.userName) : friendName
        let payerAvatarColor = isYouPaid ? appState.userAvatarColor : friendAvatarColor

        let resolvedCat: FirestoreModels.CategoryBudget? = {
            if let catId = transaction.categoryId, catId != "settlement" {
                return appState.budgetRepo.getCategory(for: catId)
            }
            return nil
        }()
        let displayCategory = resolvedCat?.category ?? transaction.subtitle ?? "Shared Expense"
        let displayIcon = isSettlement ? "arrow.turn.down.left" : (resolvedCat?.icon ?? transaction.icon ?? "person.2.fill")
        let displayColor = isSettlement ? "#34C759" : (resolvedCat?.colorHex ?? transaction.colorHex ?? "#808080")

        return SocialTransactionCardView(
            title: transaction.title,
            subtitle: subtitle,
            amount: transaction.amount,
            date: transaction.date,
            type: isSettlement ? "settlement" : transaction.type,
            category: displayCategory,
            iconName: displayIcon,
            colorHex: displayColor,
            amountColor: amountColor,
            statusBadge: statusBadge,
            payerName: payerDisplayName,
            payerAvatarColor: payerAvatarColor,
            originalAmount: transaction.originalAmount,
            currencyCode: transaction.currencyCode
        )
    }

    private var reconstructedRequest: FirestoreModels.SplitRequest? {
        guard let id = transaction.id,
              let status = FirestoreModels.SplitRequest.RequestStatus(rawValue: transaction.note ?? "")
        else { return nil }

        let isYouPaid = transaction.type == "income"
        return FirestoreModels.SplitRequest(
            id: id,
            transactionId: transaction.source ?? id,
            groupId: nil,
            fromUid: isYouPaid ? appState.currentUserId : "",
            toUid: isYouPaid ? "" : appState.currentUserId,
            fromName: isYouPaid ? (appState.userName.isEmpty ? "You" : appState.userName) : friendName,
            toName: isYouPaid ? friendName : "You",
            amount: abs(transaction.amount),
            currency: transaction.currencyCode,
            note: transaction.title,
            category: transaction.subtitle,
            icon: transaction.icon,
            colorHex: transaction.colorHex,
            status: status,
            dependencyId: nil,
            lastNudgedAt: nil,
            originalTotalAmount: transaction.originalAmount,
            createdAt: transaction.date
        )
    }
}
