import SwiftUI

struct UndoToast: View {
    let text: String
    let onUndo: () -> Void
    
    var body: some View {
        HStack {
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: onUndo) {
                Text("Undo")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#FFCC00"))
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(AppRadius.medium)
        .padding(.horizontal, 24)
        .shadow(radius: 10)
    }
}

struct BalanceCard: View {
    let name: String
    let amount: Double
    let isOwed: Bool 
    let isSelf: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileAvatar(text: String(name.prefix(1)), color: Color.random(seed: name), size: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text(isOwed ? "gets $\(String(format: "%.0f", amount))" : "owes $\(String(format: "%.0f", amount))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isOwed ? .functionalSuccess : .functionalError)
            }
        }

        .padding(16)
        .frame(width: 140) // ✅ Slightly wider for better text fit
        .background(isSelf ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemBackground))
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isSelf ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1) // ✅ Blue border for self
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2) // ✅ Soft shadow
    }
}
