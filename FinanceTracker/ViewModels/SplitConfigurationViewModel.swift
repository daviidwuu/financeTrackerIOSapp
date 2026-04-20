import Foundation
import SwiftUI
import Combine

@MainActor
final class SplitConfigurationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var splits: [FirestoreModels.Split]
    @Published var selectedFriendIds: Set<String>
    @Published var selectedGuestIds: Set<String>
    @Published var selectedGroupId: String?
    @Published var splitMode: SplitMode = .equal
    @Published var shares: [String: Int] = [:]         // splitId → share count
    @Published var percentages: [String: Double] = [:] // splitId → percentage (0–100)

    private var lockedSplitIds: Set<String> = []

    let transactionAmount: Double

    // MARK: - Init

    init(transactionAmount: Double, existingSplits: [FirestoreModels.Split], initialGroupId: String?) {
        self.transactionAmount = transactionAmount
        self.splits = existingSplits
        self.selectedGroupId = initialGroupId

        var friendIds: Set<String> = []
        var guestIds: Set<String> = []
        var initialShares: [String: Int] = [:]
        var initialPercentages: [String: Double] = [:]
        let evenPct = existingSplits.isEmpty ? 0.0 : 100.0 / Double(existingSplits.count)

        for split in existingSplits {
            if let fid = split.friendId { friendIds.insert(fid) }
            if split.isGuest, let gid = split.guestId { guestIds.insert(gid) }
            initialShares[split.id] = 1
            initialPercentages[split.id] = evenPct
        }

        self.selectedFriendIds = friendIds
        self.selectedGuestIds = guestIds
        self.shares = initialShares
        self.percentages = initialPercentages
    }

    // MARK: - Friend/Guest Selection

    func toggleFriendSelection(_ friend: FirestoreModels.Friend) {
        guard let friendId = friend.id else { return }

        if selectedFriendIds.contains(friendId) {
            selectedFriendIds.remove(friendId)
            splits.removeAll { $0.friendId == friendId }
        } else {
            selectedFriendIds.insert(friendId)
            let newSplit = FirestoreModels.Split(name: friend.name, friendId: friendId, username: friend.username, amount: 0)
            splits.append(newSplit)
            shares[newSplit.id] = 1
        }

        rebalancePercentagesIfNeeded()
        recalculateSplits(for: splitMode)
    }

    func toggleGuestSelection(_ guest: FirestoreModels.Guest) {
        guard let guestId = guest.id else { return }

        if selectedGuestIds.contains(guestId) {
            selectedGuestIds.remove(guestId)
            splits.removeAll { $0.guestId == guestId }
        } else {
            selectedGuestIds.insert(guestId)
            let newSplit = FirestoreModels.Split(name: guest.name, guestId: guestId, isGuest: true, amount: 0)
            splits.append(newSplit)
            shares[newSplit.id] = 1
            percentages[newSplit.id] = 0
        }

        rebalancePercentagesIfNeeded()
        recalculateSplits(for: splitMode)
    }

    func selectGroup(_ group: FirestoreModels.Group, allFriends: [FirestoreModels.Friend]) {
        selectedGroupId = group.id

        let membersToAdd = allFriends.filter { f in
            guard let fid = f.id else { return false }
            return group.members.contains(fid) && !selectedFriendIds.contains(fid)
        }

        for friend in membersToAdd {
            guard let fid = friend.id else { continue }
            selectedFriendIds.insert(fid)
            let newSplit = FirestoreModels.Split(name: friend.name, friendId: fid, username: friend.username, amount: 0)
            splits.append(newSplit)
            shares[newSplit.id] = 1
        }

        rebalancePercentagesIfNeeded()
        recalculateSplits(for: splitMode)
    }

    /// Called after the async guest creation completes in the view.
    func addCreatedGuest(_ guest: FirestoreModels.Guest) {
        guard let gid = guest.id else { return }
        selectedGuestIds.insert(gid)
        let newSplit = FirestoreModels.Split(name: guest.name, guestId: gid, isGuest: true, amount: 0)
        splits.append(newSplit)
        shares[newSplit.id] = 1

        rebalancePercentagesIfNeeded()
        recalculateSplits(for: splitMode)
    }

    /// Called after the async friend-add completes in the view.
    func recordFriendRequestSent(userId: String) {
        selectedFriendIds.insert(userId)
    }

    func removeSplit(_ split: FirestoreModels.Split) {
        if let fid = split.friendId { selectedFriendIds.remove(fid) }
        if let gid = split.guestId { selectedGuestIds.remove(gid) }
        splits.removeAll { $0.id == split.id }
        lockedSplitIds.remove(split.id)
        shares.removeValue(forKey: split.id)
        percentages.removeValue(forKey: split.id)
        recalculateSplits(for: splitMode)
    }

    // MARK: - Split Math

    func changeSplitMode(to mode: SplitMode) {
        splitMode = mode
        if mode == .equal { lockedSplitIds.removeAll() }
        recalculateSplits(for: mode)
    }

    func adjustSplits(manuallyChangedSplitId: String, newValue: Double) {
        lockedSplitIds.insert(manuallyChangedSplitId)
        if let i = splits.firstIndex(where: { $0.id == manuallyChangedSplitId }) {
            splits[i].amount = newValue
        }
        distributeRemainder()
    }

    func recalculateSplits(for mode: SplitMode) {
        switch mode {
        case .equal:
            lockedSplitIds.removeAll()
            distributeRemainder()

        case .exact:
            break

        case .percentage:
            for i in splits.indices {
                let pct = percentages[splits[i].id] ?? 0
                splits[i].amount = (pct / 100.0) * transactionAmount
            }

        case .shares:
            let totalShares = shares.filter { splits.map(\.id).contains($0.key) }.values.reduce(0, +)
            guard totalShares > 0 else { return }
            let unitCost = transactionAmount / Double(totalShares)
            for i in splits.indices {
                let shareCount = shares[splits[i].id] ?? 1
                splits[i].amount = Double(shareCount) * unitCost
            }
        }
    }

    // MARK: - Private Helpers

    private func distributeRemainder() {
        let lockedTotal = splits.filter { lockedSplitIds.contains($0.id) }.reduce(0) { $0 + $1.amount }
        let remainder = transactionAmount - lockedTotal
        let unlockedIndices = splits.indices.filter { !lockedSplitIds.contains(splits[$0].id) }
        guard !unlockedIndices.isEmpty else { return }

        let shareAmount = remainder / Double(unlockedIndices.count + 1)
        let roundedShare = (shareAmount * 100).rounded() / 100

        for i in unlockedIndices {
            splits[i].amount = max(0, roundedShare)
        }
    }

    private func rebalancePercentagesIfNeeded() {
        guard splitMode == .percentage, !splits.isEmpty else { return }
        let even = 100.0 / Double(splits.count)
        for split in splits {
            percentages[split.id] = even
        }
    }
}
