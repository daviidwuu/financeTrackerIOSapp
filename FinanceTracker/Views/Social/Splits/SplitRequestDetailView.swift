import SwiftUI
import MapKit
import FirebaseFirestore

struct SplitRequestDetailView: View {
    let request: FirestoreModels.SplitRequest
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var repo = SocialRepository()
    @State private var errorState = ErrorState()
    @State private var originalTransaction: FirestoreModels.TransactionModel?
    
    // Derived Properties
    private var isIncoming: Bool { request.toUid == appState.currentUserId }
    private var statusColor: Color {
        switch request.status {
        case .pending: return .orange
        case .accepted: return .blue
        case .declined: return .red
        case .paid: return .green
        case .blocked_by_group: return .secondary
        default: return .gray
        }
    }
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Standard Header
                DetailHeaderView(
                    title: request.note ?? "Split Expense",
                    onBack: { dismiss() },
                    backIcon: "xmark",
                    onMenu: nil,
                    backgroundColor: Color.backgroundPrimary,
                    textColor: .primary,
                    avatar: {
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.15))
                                .frame(width: 80, height: 80)
                                .shadow(color: statusColor.opacity(0.2), radius: 15, y: 8)
                            
                            Image(systemName: isIncoming ? "arrow.down.left" : "arrow.up.right")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(statusColor)
                        }
                    },
                    subtitle: {
                        Text(request.createdAt.formatted(date: .long, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    },
                    actions: {
                        VStack(spacing: 4) {
                            Text(String(format: "$%.2f", request.amount))
                                .font(AppTypography.prominentBalance)
                                .foregroundColor(.primary)
                            
                            // Status Pill
                            Text(request.status.rawValue.capitalized)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(statusColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(statusColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                )
                
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: AppSpacing.element)
                        
                        // 2. Info Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("DETAILS")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                        
                        VStack(spacing: 0) {
                            RequestDetailRow(
                                title: "Payer",
                                value: resolveName(uid: request.fromUid, name: request.fromName),
                                icon: "person.fill",
                                color: .blue
                            )
                            
                            Divider().padding(.leading, 52)
                            
                            RequestDetailRow(
                                title: "Recipient",
                                value: resolveName(uid: request.toUid, name: request.toName),
                                icon: "person.2.fill",
                                color: .purple
                            )
                            
                            if let groupId = request.groupId, 
                               let group = appState.groupRepo.groups.first(where: { $0.id == groupId }) {
                                Divider().padding(.leading, 52)
                                RequestDetailRow(title: "Group", value: group.name, icon: "person.3.fill", color: .orange)
                            }
                            
                            Divider().padding(.leading, 52)
                            RequestDetailRow(title: "Category", value: originalTransaction?.subtitle ?? "General", icon: "tag.fill", color: .teal)
                            
                            if let total = originalTransaction?.amount {
                                Divider().padding(.leading, 52)
                                RequestDetailRow(
                                    title: "Total Expense",
                                    value: String(format: "$%.2f", abs(total)),
                                    icon: "sum",
                                    color: .indigo
                                )
                            }
                            
                            Divider().padding(.leading, 52)
                            RequestDetailRow(
                                title: "Your Share",
                                value: String(format: "$%.2f", request.amount),
                                icon: "person.crop.circle",
                                color: .mint
                            )
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(AppRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, AppSpacing.margin)

                    // 2.5 Map (If available)
                    if let tx = originalTransaction, let lat = tx.latitude, let long = tx.longitude {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("LOCATION")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            Map(initialPosition: .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: lat, longitude: long),
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            ))) {
                                Marker("Location", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: long))
                                    .tint(.red)
                            }
                            .frame(height: 200)
                            .cornerRadius(AppRadius.medium)
                            
                            if let name = tx.locationName {
                                Text(name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .padding(.leading, 8)
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                    }
                    
                    // 3. Actions
                    VStack(spacing: 16) {
                        if isIncoming && request.status == .pending {
                            Button(action: markAsPaid) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Mark as Paid")
                                }
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .cornerRadius(AppRadius.large)
                                .shadow(color: Color.green.opacity(0.3), radius: 8, y: 4)
                            }
                            
                            Button(action: declineRequest) {
                                Text("Decline Request")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                            }
                        } else if request.fromUid == appState.currentUserId {
                            
                            // ✅ NEW: Resend feature for Declined requests
                            if request.status == .declined {
                                Button(action: resendRequest) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Resend Request")
                                    }
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.blue)
                                    .cornerRadius(AppRadius.large)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
                                }
                            }
                            
                            // Allow canceling even if declined (to clean up)
                            if request.status == .pending || request.status == .declined {
                                Button(action: cancelRequest) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Cancel Request")
                                    }
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(AppRadius.large)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.top, 16)
                }
                .padding(.bottom, 40)
            }
        }
    }
    .errorBanner(errorState)
        .navigationBarHidden(true)
        .onAppear {
            loadOriginalTransaction()
        }
    }

    private func loadOriginalTransaction() {
        let payerId = request.fromUid
        let txId = request.transactionId
        Task {
            do {
                originalTransaction = try await repo.fetchOriginalTransaction(userId: payerId, transactionId: txId)
            } catch {
                print("Error loading original transaction for map: \(error)")
            }
        }
    }

    private func resendRequest() {
        HapticManager.shared.medium()
        Task {
            do {
                guard let id = request.id else { return }
                // Reset status to pending and update timestamp to bump it up
                try await Firestore.firestore().collection("split_requests").document(id).updateData([
                    "status": "pending",
                    "createdAt": Date() // Bump to top
                ])
                dismiss()
            } catch {
                errorState.show("Failed to resend request")
            }
        }
    }
    
    private func markAsPaid() {
        HapticManager.shared.heavy()
        Task {
            do {
                try await SocialTransactionManager.shared.markSplitAsPaid(
                    request: request,
                    currentUserId: appState.currentUserId,
                    currentUserName: appState.userName
                )
                dismiss()
            } catch {
                errorState.show("Failed to mark as paid")
                HapticManager.shared.error()
            }
        }
    }
    
    private func declineRequest() {
        HapticManager.shared.medium()
        Task {
            do {
                // Using RequestRepository directly properly via AppState if possible, or SocialTransactionManager if it had it.
                // RequestRepository is in AppState.
                try await appState.requestRepo.updateRequestStatus(userId: appState.currentUserId, requestId: request.id!, status: .declined)
                dismiss()
            } catch {
                errorState.show("Failed to decline request")
            }
        }
    }
    
    private func cancelRequest() {
        HapticManager.shared.warning()
        Task {
            do {
                try await SocialTransactionManager.shared.deleteSplitRequestAndSync(request: request)
                dismiss()
            } catch {
                errorState.show("Failed to cancel request")
            }
        }
    }
    
    private func resolveName(uid: String, name: String?) -> String {
        if uid == appState.currentUserId { return "You" }
        if let name = name, !name.isEmpty, name != "Unknown" { return name }
        // Fallback lookup
        if let friend = appState.friendRepo.friends.first(where: { $0.id == uid }) { return friend.name }
        if let guest = appState.guestRepo.guests.first(where: { $0.id == uid }) { return guest.name }
        return "Unknown"
    }
}

// Reuse DetailRow or define simpler one here
struct RequestDetailRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(16)
    }
}



