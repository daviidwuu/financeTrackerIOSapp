import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class FriendDetailViewModel: ObservableObject {

    // MARK: - Undo / Optimistic State

    @Published var recentlyPaidSplitIds: Set<String> = []
    @Published var recentlyToggledTx: FirestoreModels.TransactionModel?
    @Published var showUndoToast: Bool = false

    private var undoWorkItem: DispatchWorkItem?

    // MARK: - Derived State Helpers
    // These are methods (not stored) so the view passes fresh repo data on every render.

    func visibleRequests(
        from friendTransactions: [FirestoreModels.TransactionModel],
        currentUserId: String,
        friend: FirestoreModels.Friend
    ) -> [FirestoreModels.SplitRequest] {
        friendTransactions
            .filter { !recentlyPaidSplitIds.contains($0.id ?? "") }
            .compactMap { reconstructRequest(from: $0, currentUserId: currentUserId, friend: friend) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func incomingActionRequired(
        from requests: [FirestoreModels.SplitRequest],
        currentUserId: String,
        friendName: String
    ) -> [FirestoreModels.SplitRequest] {
        requests.filter {
            $0.presentation(for: currentUserId, counterpartyName: friendName).socialBucket == .actionRequired
        }
    }

    func outgoingOutstanding(
        from requests: [FirestoreModels.SplitRequest],
        currentUserId: String,
        friendName: String
    ) -> [FirestoreModels.SplitRequest] {
        requests.filter {
            $0.presentation(for: currentUserId, counterpartyName: friendName).socialBucket == .yourRequests
        }
    }

    // MARK: - Request Reconstruction

    func reconstructRequest(
        from tx: FirestoreModels.TransactionModel,
        currentUserId: String,
        friend: FirestoreModels.Friend
    ) -> FirestoreModels.SplitRequest? {
        guard let id = tx.id else { return nil }
        let status = FirestoreModels.SplitRequest.RequestStatus(rawValue: tx.note ?? "") ?? .pending
        let isIncome = tx.type == "income"

        let fromUid = isIncome ? currentUserId : (friend.id ?? "")
        let fromName = isIncome ? "You" : friend.name
        let toUid = isIncome ? (friend.id ?? "") : currentUserId
        let toName = isIncome ? friend.name : "You"
        let originalTxId = tx.source ?? id

        return FirestoreModels.SplitRequest(
            id: id,
            transactionId: originalTxId,
            groupId: nil,
            fromUid: fromUid,
            toUid: toUid,
            fromName: fromName,
            toName: toName,
            amount: abs(tx.amount),
            currency: nil,
            note: tx.title,
            category: tx.subtitle,
            icon: tx.icon,
            colorHex: tx.colorHex,
            status: status,
            dependencyId: nil,
            lastNudgedAt: nil,
            originalTotalAmount: tx.originalAmount,
            createdAt: tx.date
        )
    }

    // MARK: - Overview Helpers

    func totalSharedByCurrency(transactions: [FirestoreModels.TransactionModel]) -> [String: Double] {
        var totals: [String: Double] = [:]
        var seen: Set<String> = []
        for tx in transactions {
            guard tx.type != "settlement" else { continue }
            let currency = tx.currencyCode ?? CurrencyManager.shared.mainCurrency
            let identity = tx.source ?? tx.id ?? UUID().uuidString
            let key = "\(currency)|\(identity)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            totals[currency, default: 0] += abs(tx.originalAmount ?? tx.amount)
        }
        return totals.filter { abs($0.value) > 0.01 }
    }

    func formatCurrencyBreakdown(_ totals: [String: Double]) -> String {
        let sorted = totals.sorted { $0.key < $1.key }
        guard !sorted.isEmpty else { return String(format: "$%.2f", 0.0) }

        func format(amount: Double, code: String) -> String {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.currencyCode = code
            f.maximumFractionDigits = 2
            f.minimumFractionDigits = 2
            return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f %@", amount, code)
        }

        if sorted.count == 1, let (code, amount) = sorted.first {
            return format(amount: amount, code: code)
        }
        return sorted.map { code, amount in "\(code) \(format(amount: amount, code: code))" }.joined(separator: "\n")
    }

    // MARK: - Data Loading

    func loadData(friendId: String?, currentUserId: String, repo: SocialRepository) {
        guard let fid = friendId else { return }
        repo.fetchFriendTransactions(currentUserId: currentUserId, friendId: fid)
    }

    // MARK: - Expense Operations

    func handleAddExpense(
        amount: Double,
        note: String,
        category: FirestoreModels.CategoryBudget?,
        splits: [FirestoreModels.Split],
        originalAmount: Double?,
        currencyCode: String?,
        exchangeRate: Double?,
        currentUserId: String,
        userName: String,
        friendCache: [FirestoreModels.Friend],
        groupCache: [FirestoreModels.Group],
        onComplete: @escaping () -> Void
    ) {
        let transaction = FirestoreModels.TransactionModel(
            userId: currentUserId,
            title: note.isEmpty ? (category?.category ?? "Expense") : note,
            subtitle: category?.category,
            categoryId: category?.id,
            amount: -abs(amount),
            date: Date(),
            type: "expense",
            createdAt: Date(),
            icon: category?.icon,
            colorHex: category?.colorHex,
            note: note,
            splits: splits,
            originalAmount: originalAmount,
            currencyCode: currencyCode,
            exchangeRate: exchangeRate
        )
        Task {
            do {
                _ = try await SocialTransactionManager.shared.createSocialTransaction(
                    transaction: transaction,
                    payerUid: currentUserId,
                    payerName: userName,
                    groupId: nil,
                    friendCache: friendCache,
                    groupCache: groupCache
                )
                HapticManager.shared.success()
                onComplete()
            } catch {
                DebugLogger.log("Error adding friend expense: \(error)")
                HapticManager.shared.error()
            }
        }
    }

    func handleUpdateTransaction(
        originalTx: FirestoreModels.TransactionModel,
        amount: Double,
        note: String,
        category: FirestoreModels.CategoryBudget?,
        splits: [FirestoreModels.Split],
        originalAmount: Double?,
        currencyCode: String?,
        exchangeRate: Double?,
        currentUserId: String,
        userName: String,
        friendCache: [FirestoreModels.Friend],
        groupCache: [FirestoreModels.Group],
        budgetRepo: BudgetRepository,
        onComplete: @escaping () -> Void
    ) {
        let resolvedCatId = category?.id ?? originalTx.categoryId
        let resolvedCategory = category ?? resolvedCatId.flatMap { budgetRepo.getCategory(for: $0) }

        let transaction = FirestoreModels.TransactionModel(
            id: originalTx.id,
            userId: currentUserId,
            title: note.isEmpty ? (resolvedCategory?.category ?? "Expense") : note,
            subtitle: resolvedCategory?.category,
            categoryId: resolvedCatId,
            amount: -abs(amount),
            date: originalTx.date,
            type: originalTx.type,
            createdAt: originalTx.createdAt,
            icon: resolvedCategory?.icon,
            colorHex: resolvedCategory?.colorHex,
            note: note,
            splits: splits,
            originalAmount: originalAmount ?? originalTx.originalAmount,
            currencyCode: currencyCode ?? originalTx.currencyCode,
            exchangeRate: exchangeRate ?? originalTx.exchangeRate
        )
        Task {
            do {
                _ = try await SocialTransactionManager.shared.createSocialTransaction(
                    transaction: transaction,
                    payerUid: currentUserId,
                    payerName: userName,
                    groupId: nil,
                    friendCache: friendCache,
                    groupCache: groupCache
                )
                HapticManager.shared.success()
                onComplete()
            } catch {
                DebugLogger.log("Error updating friend expense: \(error)")
                HapticManager.shared.error()
            }
        }
    }

    // MARK: - Accept Request

    func acceptRequest(
        _ request: FirestoreModels.SplitRequest,
        transaction: TransactionFormData,
        currentUserId: String,
        onComplete: @escaping () -> Void
    ) {
        Task {
            do {
                let accepted = transaction.firestoreModel(userId: currentUserId)
                _ = try await SocialTransactionManager.shared.acceptSplitRequest(
                    request: request,
                    acceptedTransaction: accepted,
                    currentUserId: currentUserId
                )
                NotificationManager.shared.sendTransactionNotification(
                    amount: accepted.amount,
                    category: transaction.title,
                    type: transaction.type,
                    originalAmount: transaction.originalAmount,
                    currencyCode: transaction.currencyCode
                )
                onComplete()
            } catch {
                DebugLogger.log("Failed to accept friend split request: \(error)")
                HapticManager.shared.error()
            }
        }
    }

    // MARK: - Split Card Actions

    func handleSplitCardAction(
        _ action: RequestAction,
        split: FirestoreModels.SplitRequest,
        currentUserId: String,
        currentUserName: String,
        friendTransactions: [FirestoreModels.TransactionModel],
        onLoadData: @escaping () -> Void,
        onRequestToAccept: @escaping (FirestoreModels.SplitRequest) -> Void
    ) {
        switch action {
        case .acceptSplit:
            onRequestToAccept(split)
        case .declineSplit:
            resolveSplitAction(split, currentUserId: currentUserId, onLoadData: onLoadData)
        case .acceptSettlement:
            acceptSettlement(split, currentUserId: currentUserId, currentUserName: currentUserName, onLoadData: onLoadData)
        case .declineSettlement:
            declineSettlement(split, onLoadData: onLoadData)
        case .confirmPaymentReceived:
            handleSplitToggle(split, currentUserId: currentUserId, currentUserName: currentUserName, friendTransactions: friendTransactions, onLoadData: onLoadData)
        case .cancelRequest:
            resolveSplitAction(split, currentUserId: currentUserId, onLoadData: onLoadData)
        case .resendRequest:
            resendRequest(split, currentUserId: currentUserId, onLoadData: onLoadData)
        case .nudge:
            Task {
                try? await SocialTransactionManager.shared.nudgeSplitRequest(request: split)
                HapticManager.shared.success()
            }
        }
    }

    // MARK: - Toggle / Undo

    func handleSplitToggle(
        _ split: FirestoreModels.SplitRequest,
        currentUserId: String,
        currentUserName: String,
        friendTransactions: [FirestoreModels.TransactionModel],
        onLoadData: @escaping () -> Void
    ) {
        guard split.canCurrentUserConfirmPaymentReceived(currentUserId: currentUserId) else {
            HapticManager.shared.error()
            return
        }
        HapticManager.shared.success()
        withAnimation { if let id = split.id { recentlyPaidSplitIds.insert(id) } }
        recentlyToggledTx = friendTransactions.first { $0.id == split.id }
        withAnimation { showUndoToast = true }
        undoWorkItem?.cancel()

        Task {
            do {
                _ = try await SocialTransactionManager.shared.markSplitAsPaid(request: split, currentUserId: currentUserId, currentUserName: currentUserName)
                onLoadData()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if let id = split.id { recentlyPaidSplitIds.remove(id) }
            } catch {
                if let id = split.id { recentlyPaidSplitIds.remove(id) }
            }
        }

        let workItem = DispatchWorkItem { [weak self] in
            withAnimation { self?.showUndoToast = false; self?.recentlyToggledTx = nil }
        }
        undoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    func undoToggle(
        currentUserId: String,
        currentUserName: String,
        friend: FirestoreModels.Friend,
        onLoadData: @escaping () -> Void
    ) {
        guard let tx = recentlyToggledTx,
              let req = reconstructRequest(from: tx, currentUserId: currentUserId, friend: friend)
        else { return }
        let targetStatus = (tx.note ?? "").lowercased()
        HapticManager.shared.medium()

        Task {
            do {
                if targetStatus == "paid" {
                    _ = try await SocialTransactionManager.shared.markSplitAsPaid(request: req, currentUserId: currentUserId, currentUserName: currentUserName)
                } else {
                    try await SocialTransactionManager.shared.unmarkSplitAsPaid(request: req, currentUserId: currentUserId)
                }
                showUndoToast = false
                if let id = req.id { recentlyPaidSplitIds.remove(id) }
                onLoadData()
            } catch {
                DebugLogger.log("Error undoing toggle: \(error)")
            }
        }
    }

    func toggleTransactionStatus(
        _ transaction: FirestoreModels.TransactionModel,
        currentUserId: String,
        currentUserName: String,
        friend: FirestoreModels.Friend,
        onLoadData: @escaping () -> Void
    ) {
        guard let req = reconstructRequest(from: transaction, currentUserId: currentUserId, friend: friend) else { return }
        let isPaid = req.status == .paid
        let canConfirm = req.canCurrentUserConfirmPaymentReceived(currentUserId: currentUserId)
        let canUndo = req.canCurrentUserUndoPaymentReceived(currentUserId: currentUserId)
        guard (!isPaid && canConfirm) || (isPaid && canUndo) else { HapticManager.shared.error(); return }

        HapticManager.shared.medium()
        recentlyToggledTx = transaction

        Task {
            do {
                if !isPaid {
                    _ = try await SocialTransactionManager.shared.markSplitAsPaid(request: req, currentUserId: currentUserId, currentUserName: currentUserName)
                } else {
                    try await SocialTransactionManager.shared.unmarkSplitAsPaid(request: req, currentUserId: currentUserId)
                }
                showUndoToast = true
                onLoadData()
                undoWorkItem?.cancel()
                let workItem = DispatchWorkItem { [weak self] in withAnimation { self?.showUndoToast = false } }
                undoWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
            } catch {
                DebugLogger.log("Error toggling: \(error)")
            }
        }
    }

    // MARK: - Delete

    func deleteTransaction(_ transaction: FirestoreModels.TransactionModel, repo: SocialRepository, onLoadData: @escaping () -> Void) {
        guard let id = transaction.id else { return }
        HapticManager.shared.light()
        withAnimation { repo.removeLocalTransaction(id: id) }
        Task {
            do { try await repo.deleteFriendTransaction(transactionId: id) }
            catch { onLoadData() }
        }
    }

    // MARK: - Settlement / Resolve

    private func acceptSettlement(
        _ split: FirestoreModels.SplitRequest,
        currentUserId: String,
        currentUserName: String,
        onLoadData: @escaping () -> Void
    ) {
        HapticManager.shared.success()
        Task {
            do {
                try await SocialTransactionManager.shared.acceptSettlement(request: split, currentUserId: currentUserId, currentUserName: currentUserName)
                onLoadData()
            } catch { HapticManager.shared.error() }
        }
    }

    private func declineSettlement(_ split: FirestoreModels.SplitRequest, onLoadData: @escaping () -> Void) {
        HapticManager.shared.heavy()
        Task {
            do { try await SocialTransactionManager.shared.declineSettlement(request: split); onLoadData() }
            catch { HapticManager.shared.error() }
        }
    }

    private func resolveSplitAction(
        _ split: FirestoreModels.SplitRequest,
        currentUserId: String,
        onLoadData: @escaping () -> Void
    ) {
        HapticManager.shared.heavy()
        withAnimation { if let id = split.id { recentlyPaidSplitIds.insert(id) } }
        Task {
            do {
                try await SocialTransactionManager.shared.resolveSplitRequestAction(request: split)
                onLoadData()
            } catch {
                HapticManager.shared.error()
                if let id = split.id { recentlyPaidSplitIds.remove(id) }
            }
        }
    }

    private func resendRequest(
        _ split: FirestoreModels.SplitRequest,
        currentUserId: String,
        onLoadData: @escaping () -> Void
    ) {
        guard let id = split.id else { return }
        HapticManager.shared.medium()
        Task {
            do {
                try await Firestore.firestore().collection("split_requests").document(id).updateData([
                    "status": FirestoreModels.SplitRequest.RequestStatus.pending.rawValue,
                    "createdAt": Date(),
                    "lastUpdatedBy": currentUserId
                ])
                onLoadData()
            } catch {
                DebugLogger.log("Failed to resend friend split request: \(error)")
                HapticManager.shared.error()
            }
        }
    }
}
