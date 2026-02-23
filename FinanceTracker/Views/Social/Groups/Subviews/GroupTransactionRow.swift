import SwiftUI
import FirebaseFirestore

struct GroupTransactionRow: View {
    let transaction: FirestoreModels.GroupTransaction
    let currentUserId: String
    
    // We need appState to check for "You" logic properly, but it's not passed in.
    // Ideally, we should pass in the current user's name or use EnvironmentObject if available.
    // Since this is a subview, we can use @EnvironmentObject.
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        let displayTitle = (transaction.note?.isEmpty == false) ? transaction.note! : transaction.title
        let payerName = (transaction.payerId == currentUserId) ? "You" : transaction.payerName
        
        let subtitle: String
        let statusBadge: String?
        
        if transaction.type == "settlement" {
            // Determine settlement status from involvedUserStatuses
            if let statuses = transaction.involvedUserStatuses,
               let receiverId = transaction.receiverId {
                let receiverStatus = statuses[receiverId] ?? "pending"
                statusBadge = receiverStatus == "paid" ? "Paid" : receiverStatus == "declined" ? "Declined" : "Pending"
            } else {
                statusBadge = "Pending"
            }
            
            // Build subtitle: "You paid X" / "X paid you" / "X paid Y"
            let receiverDisplay: String = {
                if let rid = transaction.receiverId, rid == currentUserId {
                    return "you"
                } else if let rname = transaction.receiverName {
                    return rname
                }
                return "settlement"
            }()
            
            if transaction.payerId == currentUserId {
                subtitle = "You paid \(receiverDisplay)"
            } else if transaction.receiverId == currentUserId {
                subtitle = "\(transaction.payerName) paid you"
            } else {
                subtitle = "\(transaction.payerName) paid \(receiverDisplay)"
            }
        } else {
            var dynamicBadge: String? = nil
            
            if let statuses = transaction.involvedUserStatuses, !statuses.isEmpty {
                if transaction.payerId == appState.currentUserId {
                    // Current User is the Payer
                    let hasBlocking = statuses.values.contains("pending") || statuses.values.contains("declined")
                    if hasBlocking {
                        dynamicBadge = "Awaiting Payments"
                    } else {
                        let allPaid = statuses.values.allSatisfy { $0 == "paid" }
                        if allPaid {
                            dynamicBadge = "Fully Paid"
                        } else {
                            let allAcceptedOrPaid = statuses.values.allSatisfy { $0 == "accepted" || $0 == "paid" }
                            dynamicBadge = allAcceptedOrPaid ? "All Accepted" : nil
                        }
                    }
                } else if let myStatus = statuses[appState.currentUserId] {
                    // Current User is a Debtor
                    if myStatus == "pending" {
                        dynamicBadge = "You Owe"
                    } else if myStatus == "accepted" {
                        dynamicBadge = "Accepted"
                    } else if myStatus == "paid" {
                        dynamicBadge = "Paid"
                    }
                }
            }
            
            statusBadge = dynamicBadge
            subtitle = "\(payerName) paid"
        }
        
        // Settlement color: expense for payer, income for receiver
        let amountColor: Color = {
            if transaction.type == "settlement" {
                if transaction.payerId == currentUserId {
                    return .primary // Expense color for payer
                } else if transaction.receiverId == currentUserId {
                    return .green // Income color for receiver
                }
                return .primary
            }
            return (transaction.type == "income") ? .green : .primary
        }()
        
        return SocialTransactionCardView(
            title: displayTitle,
            subtitle: subtitle,
            amount: transaction.amount,
            date: transaction.date,
            type: transaction.type,
            category: transaction.category,
            iconName: transaction.icon,
            colorHex: transaction.colorHex,
            amountColor: amountColor,
            statusBadge: statusBadge
        )
    }
}
