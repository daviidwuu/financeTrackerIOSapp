import SwiftUI
import FirebaseFirestore

struct DebtInstructionRow: View {
    let debtorName: String
    let creditorName: String
    let amount: Double
    var currency: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                ProfileAvatar(text: String(debtorName.prefix(1)), color: .secondary, size: 32)
                Text(debtorName).font(.subheadline).fontWeight(.medium).lineLimit(1)
            }
            Image(systemName: "arrow.right").font(.caption).foregroundColor(.secondary)
            HStack(spacing: 8) {
                ProfileAvatar(text: String(creditorName.prefix(1)), color: .secondary, size: 32)
                Text(creditorName).font(.subheadline).fontWeight(.medium).lineLimit(1)
            }
            Spacer()
            Text("\(currency.isEmpty ? "$" : currency) \(String(format: "%.2f", amount))").font(.subheadline).fontWeight(.bold)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.small)
    }
}
