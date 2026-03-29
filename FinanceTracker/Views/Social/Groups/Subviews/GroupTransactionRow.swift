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
        let payerName = appState.userResolver.resolveName(for: transaction.payerId, fallbackName: transaction.payerName)
        
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
                } else if let rid = transaction.receiverId {
                    return appState.userResolver.resolveName(for: rid, fallbackName: transaction.receiverName)
                }
                return "settlement"
            }()
            
            if transaction.payerId == currentUserId {
                subtitle = "You paid \(receiverDisplay)"
            } else if transaction.receiverId == currentUserId {
                let resolvedPayerName = appState.userResolver.resolveName(for: transaction.payerId, fallbackName: transaction.payerName)
                subtitle = "\(resolvedPayerName) paid you"
            } else {
                let resolvedPayerName = appState.userResolver.resolveName(for: transaction.payerId, fallbackName: transaction.payerName)
                subtitle = "\(resolvedPayerName) paid \(receiverDisplay)"
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
                    return Color.functionalSuccess // Income color for receiver
                }
                return .primary
            }
            return (transaction.type == "income") ? Color.functionalSuccess : .primary
        }()
        
        // ✅ FIX: Resolve category dynamically from categoryId
        let resolvedCat: FirestoreModels.CategoryBudget? = {
            if let catId = transaction.categoryId {
                return appState.budgetRepo.getCategory(for: catId)
            }
            return nil
        }()
        let displayCategory = resolvedCat?.category ?? transaction.category ?? "Shared Expense"
        let displayIcon = transaction.type == "settlement" ? "arrow.turn.down.left" : (resolvedCat?.icon ?? transaction.icon ?? "person.2.fill")
        let displayColor = transaction.type == "settlement" ? "#34C759" : (resolvedCat?.colorHex ?? transaction.colorHex ?? "#808080")
        
        return SocialTransactionCardView(
            title: displayTitle,
            subtitle: subtitle,
            amount: transaction.amount,
            date: transaction.date,
            type: transaction.type,
            category: displayCategory,
            iconName: displayIcon,
            colorHex: displayColor,
            amountColor: amountColor,
            statusBadge: statusBadge,
            payerName: payerName,
            originalAmount: transaction.originalAmount,
            currencyCode: transaction.currencyCode
        )
    }
}
