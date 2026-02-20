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
        HStack(spacing: AppSpacing.element) {
            CategoryIconView(
                category: transaction.category,
                iconOverride: transaction.icon,
                colorOverride: transaction.colorHex,
                type: transaction.type
            )
            
            VStack(alignment: .leading, spacing: 4) {
                let displayTitle = (transaction.note?.isEmpty == false) ? transaction.note! : transaction.title
                Text(displayTitle)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                let payerName = (transaction.payerId == currentUserId) ? "You" : transaction.payerName
                HStack(spacing: 4) {
                    if transaction.type == "settlement" {
                        if let receiver = transaction.receiverName {
                            // If receiver is me, show "You"
                            // If payer is me, show "You paid X"
                            let receiverDisplay: String = {
                                if let rid = transaction.receiverId, rid == appState.currentUserId {
                                    return "You"
                                } else if receiver == appState.userName {
                                    return "You"
                                }
                                return receiver
                            }()
                            
                            Text("\(payerName) paid \(receiverDisplay)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        } else {
                            Text("\(payerName) paid settlement")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("\(payerName) paid")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", abs(transaction.amount)))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(transaction.type == "settlement" || transaction.type == "income" ? .green : .primary)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.tertiaryLabel)
            }
        }
        .padding(AppSpacing.element)
    }
}
