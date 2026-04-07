import Foundation

enum RequestViewerRole: Equatable {
    case sender
    case receiver
    case observer
}

enum RequestKind: Equatable {
    case split
    case settlement
}

enum RequestSocialBucket: Equatable {
    case actionRequired
    case yourRequests
}

enum RequestActionEmphasis: Equatable {
    case primary
    case secondary
    case destructive
}

enum RequestAction: Equatable {
    case acceptSplit
    case declineSplit
    case acceptSettlement
    case declineSettlement
    case confirmPaymentReceived
    case cancelRequest
    case resendRequest
    case nudge

    var title: String {
        switch self {
        case .acceptSplit:
            return "Accept Request"
        case .declineSplit:
            return "Decline Request"
        case .acceptSettlement:
            return "Accept Settlement"
        case .declineSettlement:
            return "Decline Settlement"
        case .confirmPaymentReceived:
            return "Confirm Payment Received"
        case .cancelRequest:
            return "Cancel Request"
        case .resendRequest:
            return "Resend Request"
        case .nudge:
            return "Send Reminder"
        }
    }

    var iconName: String {
        switch self {
        case .acceptSplit, .acceptSettlement:
            return "checkmark.circle.fill"
        case .declineSplit, .declineSettlement:
            return "xmark.circle"
        case .confirmPaymentReceived:
            return "banknote.fill"
        case .cancelRequest:
            return "trash"
        case .resendRequest:
            return "arrow.clockwise"
        case .nudge:
            return "bell.badge.fill"
        }
    }

    var compactIconName: String {
        switch self {
        case .acceptSplit, .acceptSettlement:
            return "checkmark"
        case .declineSplit, .declineSettlement, .cancelRequest:
            return "xmark"
        case .confirmPaymentReceived:
            return "banknote.fill"
        case .resendRequest:
            return "arrow.clockwise"
        case .nudge:
            return "bell.badge.fill"
        }
    }

    var emphasis: RequestActionEmphasis {
        switch self {
        case .acceptSplit, .acceptSettlement, .confirmPaymentReceived, .resendRequest, .nudge:
            return .primary
        case .declineSplit, .declineSettlement:
            return .secondary
        case .cancelRequest:
            return .destructive
        }
    }
}

struct RequestPresentation: Equatable {
    let role: RequestViewerRole
    let kind: RequestKind
    let title: String
    let subtitle: String
    let badge: String
    let detailMessage: String?
    let timestampPrefix: String
    let primaryAction: RequestAction?
    let secondaryAction: RequestAction?
    let isVisibleOnHome: Bool
    let socialBucket: RequestSocialBucket?
    let canConfirmPaymentReceived: Bool
    let canUndoPaymentReceived: Bool

    var cardBadge: String? {
        badge == "Needs Response" ? nil : badge
    }
}

extension FirestoreModels.SplitRequest {
    var requestKind: RequestKind {
        isSettlement == true ? .settlement : .split
    }

    func presentation(for currentUserId: String, counterpartyName overrideName: String? = nil) -> RequestPresentation {
        let role = viewerRole(for: currentUserId)
        let kind = requestKind
        let counterpartyName = resolvedCounterpartyName(for: role, overrideName: overrideName)
        let amountText = CurrencyFormatter.format(amount, currencyCode: resolvedCurrency)
        let noteText = resolvedNoteText(for: kind)
        let badge = badgeText(role: role, kind: kind)
        let actions = resolvedActions(role: role, kind: kind)

        return RequestPresentation(
            role: role,
            kind: kind,
            title: counterpartyName,
            subtitle: subtitleText(
                counterpartyName: counterpartyName,
                role: role,
                kind: kind,
                amountText: amountText,
                noteText: noteText
            ),
            badge: badge,
            detailMessage: detailMessage(role: role, kind: kind, badge: badge),
            timestampPrefix: role == .sender ? "Sent" : "Requested",
            primaryAction: actions.primary,
            secondaryAction: actions.secondary,
            isVisibleOnHome: role == .receiver && status == .pending,
            socialBucket: socialBucket(role: role),
            canConfirmPaymentReceived: canCurrentUserConfirmPaymentReceived(currentUserId: currentUserId),
            canUndoPaymentReceived: canCurrentUserUndoPaymentReceived(currentUserId: currentUserId)
        )
    }

    func viewerRole(for currentUserId: String) -> RequestViewerRole {
        if currentUserId == fromUid {
            return .sender
        }
        if currentUserId == toUid {
            return .receiver
        }
        return .observer
    }

    func canCurrentUserConfirmPaymentReceived(currentUserId: String) -> Bool {
        guard viewerRole(for: currentUserId) == .sender, requestKind == .split else {
            return false
        }

        if isGuest == true {
            return status == .pending || status == .accepted || status == .declined
        }

        return status == .accepted
    }

    func canCurrentUserUndoPaymentReceived(currentUserId: String) -> Bool {
        viewerRole(for: currentUserId) == .sender && requestKind == .split && status == .paid
    }

    var revertStatusAfterUndoPayment: RequestStatus {
        isGuest == true ? .pending : .accepted
    }

    private func resolvedCounterpartyName(for role: RequestViewerRole, overrideName: String?) -> String {
        if let overrideName, !overrideName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return overrideName
        }

        switch role {
        case .sender:
            return normalizedDisplayName(toName, fallback: toUid == "guest" ? "Guest" : "Friend")
        case .receiver:
            return normalizedDisplayName(fromName, fallback: "Friend")
        case .observer:
            return normalizedDisplayName(fromName, fallback: "Request")
        }
    }

    private func normalizedDisplayName(_ value: String?, fallback: String) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }
        return value
    }

    private func resolvedNoteText(for kind: RequestKind) -> String {
        if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return note
        }
        return kind == .settlement ? "Settlement" : "Expense"
    }

    private func badgeText(role: RequestViewerRole, kind: RequestKind) -> String {
        switch status {
        case .pending:
            if kind == .settlement {
                return "Settlement Request"
            }
            switch role {
            case .receiver:
                return "Needs Response"
            case .sender:
                return (isGuest == true) ? "Awaiting Payment" : "Waiting for Response"
            case .observer:
                return "Pending"
            }
        case .accepted:
            if kind == .split && role == .sender {
                return "Awaiting Payment"
            }
            return "Accepted"
        case .paid:
            return "Paid"
        case .declined:
            return "Declined"
        case .blocked_by_group:
            return "Blocked by Group"
        case .blocked_by_friendship:
            return "Blocked by Friendship"
        case .unknown:
            return "Unknown"
        }
    }

    private func subtitleText(counterpartyName: String, role: RequestViewerRole, kind: RequestKind, amountText: String, noteText: String) -> String {
        if kind == .settlement {
            switch role {
            case .sender:
                return status == .paid ? "Settlement completed for \(amountText)" : "Settlement for \(amountText)"
            case .receiver:
                return "\(counterpartyName) logged a settlement for \(amountText)"
            case .observer:
                return "Settlement for \(amountText)"
            }
        }

        switch role {
        case .sender:
            if canCurrentUserConfirmPaymentReceived(currentUserId: fromUid) {
                return "\(counterpartyName) owes \(amountText) for \(noteText)"
            }
            if status == .declined {
                return "Request declined for \(amountText) • \(noteText)"
            }
            return "Waiting on \(counterpartyName) for \(amountText) • \(noteText)"
        case .receiver:
            return "\(counterpartyName) requests \(amountText) for \(noteText)"
        case .observer:
            return "\(amountText) • \(noteText)"
        }
    }

    private func detailMessage(role: RequestViewerRole, kind: RequestKind, badge: String) -> String? {
        switch (role, kind, status) {
        case (.receiver, .split, .accepted):
            return "You accepted this request. The sender will confirm payment once it is received."
        case (.sender, .split, .accepted):
            return "Confirm payment once you have received it."
        case (.sender, .split, .pending) where isGuest == true:
            return "Guest splits do not require acceptance. Confirm payment when you receive it."
        case (.sender, .split, .pending):
            return "Waiting for the other person to respond before payment can be confirmed."
        case (.receiver, .settlement, .pending):
            return "Review this settlement and accept it if it matches the payment you received."
        case (.sender, .settlement, .pending):
            return "Waiting for the other person to confirm this settlement."
        case (_, _, .declined):
            return "This request was declined."
        case (_, _, .paid):
            return "This request has been settled."
        case (_, _, .blocked_by_group), (_, _, .blocked_by_friendship):
            return badge
        default:
            return nil
        }
    }

    private func resolvedActions(role: RequestViewerRole, kind: RequestKind) -> (primary: RequestAction?, secondary: RequestAction?) {
        switch (role, kind, status) {
        case (.receiver, .split, .pending):
            return (.acceptSplit, .declineSplit)
        case (.receiver, .settlement, .pending):
            return (.acceptSettlement, .declineSettlement)
        case (.sender, .split, .pending) where isGuest == true:
            return (.confirmPaymentReceived, .cancelRequest)
        case (.sender, _, .pending):
            return (.nudge, .cancelRequest)
        case (.sender, .split, .accepted):
            return (.confirmPaymentReceived, nil)
        case (.sender, _, .declined):
            return (.resendRequest, .cancelRequest)
        default:
            return (nil, nil)
        }
    }

    private func socialBucket(role: RequestViewerRole) -> RequestSocialBucket? {
        switch role {
        case .receiver where status == .pending:
            return .actionRequired
        case .sender where status == .pending || status == .accepted:
            return .yourRequests
        default:
            return nil
        }
    }
}
