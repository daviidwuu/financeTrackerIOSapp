import SwiftUI
import FirebaseFirestore

struct PendingSplitCard: View {
    let split: FirestoreModels.SplitRequest
    let userId: String
    let onToggle: () -> Void
    let onDelete: () -> Void
    var onNudge: (() -> Void)? = nil
    
    /// Whether the current user is the sender (creditor) of this split request
    private var isSender: Bool { split.fromUid == userId }
    
    // Helper to determine display name
    private var displayName: String {
        if isSender {
            return split.toName ?? "Friend"   // Sender sees who they requested from
        } else {
            return split.fromName ?? "Friend" // Receiver sees who requested
        }
    }
    
    private var accentColor: Color { isSender ? .green : .orange }
    
    var body: some View {
        HStack(spacing: AppSpacing.element) {
            // Icon
            Circle()
                .fill(accentColor.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: split.isSettlement == true ? "arrow.left.arrow.right" : (isSender ? "creditcard.fill" : "arrow.up.right"))
                        .font(.headline)
                        .foregroundColor(accentColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    // FIX 3.5: Guest indicator badge
                    if split.isGuest == true {
                        Text("Guest")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary)
                            .clipShape(Capsule())
                    }
                }
                
                if split.isSettlement == true {
                    if isSender {
                        Text("You paid $\(String(format: "%.2f", split.amount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("paid you $\(String(format: "%.2f", split.amount))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    let note = split.note?.isEmpty == false ? split.note! : "Expense"
                    if isSender {
                        Text("You requested $\(String(format: "%.2f", split.amount)) for \(note)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("requests $\(String(format: "%.2f", split.amount)) for \(note)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                // Time
                Text(isSender ? "Sent \(timeAgo(from: split.createdAt))" : "Requested \(timeAgo(from: split.createdAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // FIX 3.5: Guest explanation
                if split.isGuest == true {
                    Text("Manual tracking — no account")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if isSender {
                    // Sender: Cancel + Nudge
                    Button(action: {
                        HapticManager.shared.light()
                        onDelete()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        HapticManager.shared.light()
                        onNudge?()
                    }) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Receiver: Decline + Accept
                    Button(action: {
                        HapticManager.shared.light()
                        onDelete()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Accept / Pay
                    Button(action: {
                        onToggle()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.backgroundPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.functionalIncome)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(AppSpacing.element)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(accentColor, lineWidth: 1)
        )
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
