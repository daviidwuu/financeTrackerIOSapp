import SwiftUI
import MapKit
import FirebaseFirestore

struct SplitRequestDetailView: View {
    let request: FirestoreModels.SplitRequest
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userPremiumRepo: UserPremiumRepository
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var repo = SocialRepository()
    @State private var errorState = ErrorState()
    @State private var originalTransaction: FirestoreModels.TransactionModel?
    @State private var allSplits: [FirestoreModels.SplitRequest] = []
    @State private var showAcceptWizard = false
    @State private var showFullMap = false
    
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
            Color.backgroundPrimary.ignoresSafeArea(.all, edges: .bottom)
            
            VStack(spacing: 0) {
                // 1. Slim Header (nav bar + title only)
                DetailHeaderView(
                    title: "",
                    subtitle: nil as String?,
                    onBack: { dismiss() },
                    backIcon: "xmark",
                    onMenu: nil,
                    backgroundColor: Color.backgroundPrimary,
                    textColor: .primary,
                    height: AppSize.headerHeightSlim,
                    avatar: { EmptyView() },
                    actions: { EmptyView() }
                )
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Section: Icon, Amount, Status, Date
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(statusColor.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                    .shadow(color: statusColor.opacity(0.2), radius: 15, y: 8)
                                
                                Image(systemName: isIncoming ? "arrow.down.left" : "arrow.up.right")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(statusColor)
                            }
                            
                            Text(request.note?.isEmpty == false ? request.note! : "Split Request")
                                .font(AppTypography.titleDisplay)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            let categoryName: String = {
                                if let id = originalTransaction?.categoryId, let cat = appState.budgetRepo.getCategory(for: id) {
                                    return cat.category
                                }
                                return "Split Expense"
                            }()
                            
                            Text(categoryName)
                                .font(AppTypography.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
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
                            
                            Text(request.createdAt.formatted(date: .long, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.element)
                        
                        // 2. Split Status Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SPLIT STATUS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 0) {
                                if allSplits.isEmpty {
                                    HStack(spacing: 12) {
                                        ProgressView()
                                        Text("Loading split status")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                } else {
                                    ForEach(Array(allSplits.enumerated()), id: \.element.id) { index, split in
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(splitStatusColor(split.status).opacity(0.15))
                                                .frame(width: 36, height: 36)
                                                .overlay(
                                                    Image(systemName: splitStatusIcon(split.status))
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(splitStatusColor(split.status))
                                                )
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack(spacing: 8) {
                                                    Text(resolveName(uid: split.toUid, name: split.toName))
                                                        .font(.body)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.primary)
                                                    
                                                    if userPremiumRepo.isPremium(userId: split.toUid) == true {
                                                        PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: split.toUid))
                                                    }
                                                }

                                                Text(split.status.rawValue.capitalized)
                                                    .font(.caption)
                                                    .foregroundColor(splitStatusColor(split.status))
                                            }
                                            
                                            Spacer()
                                            
                                            Text(String(format: "$%.2f", split.amount))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        
                                        if index < allSplits.count - 1 {
                                            Divider().padding(.leading, 64)
                                        }
                                    }
                                }
                            }
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        
                        // 3. Details & Map Card (matches TransactionDetailView)
                        VStack(alignment: .leading, spacing: 16) {
                            Text("DETAILS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 0) {
                                // Map Header (integrated into card)
                                if let lat = request.latitude ?? originalTransaction?.latitude,
                                   let long = request.longitude ?? originalTransaction?.longitude {
                                    Map(initialPosition: .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: long), distance: 500))) {
                                        Marker(request.note ?? "Location", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: long))
                                    }
                                    .allowsHitTesting(false)
                                    .frame(height: 140)
                                    .overlay(
                                        Color.black.opacity(0.001)
                                            .onTapGesture { HapticManager.shared.light();  showFullMap = true }
                                    )
                                    
                                    Divider()
                                }
                                
                                TransactionDetailRow(
                                    icon: "person.fill",
                                    title: "Payer",
                                    color: .secondary
                                ) {
                                    HStack(spacing: 8) {
                                        Text(resolveName(uid: request.fromUid, name: request.fromName))
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        if userPremiumRepo.isPremium(userId: request.fromUid) == true {
                                            PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: request.fromUid))
                                        }
                                    }
                                }

                                Divider().padding(.leading, 52)
                                
                                TransactionDetailRow(
                                    icon: "person.2.fill",
                                    title: "Recipient",
                                    color: .secondary
                                ) {
                                    HStack(spacing: 8) {
                                        Text(resolveName(uid: request.toUid, name: request.toName))
                                            .font(.body)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        if userPremiumRepo.isPremium(userId: request.toUid) == true {
                                            PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: request.toUid))
                                        }
                                    }
                                }
                                
                                if let groupId = request.groupId,
                                   let group = appState.groupRepo.groups.first(where: { $0.id == groupId }) {
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(icon: "person.3.fill", title: "Group", value: group.name, color: .secondary)
                                }
                                
                                Divider().padding(.leading, 52)
                                TransactionDetailRow(icon: "tag", title: "Category", value: originalTransaction?.categoryId ?? "General", color: .primary)
                                
                                Divider().padding(.leading, 52)
                                TransactionDetailRow(
                                    icon: "banknote",
                                    title: "Original Amount",
                                    value: String(format: "$%.2f", request.originalTotalAmount ?? originalTransaction?.originalAmount ?? abs(originalTransaction?.amount ?? request.amount)),
                                    color: .blue
                                )
                                
                                Divider().padding(.leading, 52)
                                TransactionDetailRow(
                                    icon: "person.crop.circle",
                                    title: "Your Share",
                                    value: String(format: "$%.2f", request.amount),
                                    color: .secondary
                                )
                                
                                if let note = request.note, !note.isEmpty {
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(
                                        icon: "text.alignleft",
                                        title: "Notes",
                                        value: note,
                                        color: .secondary
                                    )
                                }
                                
                                Divider().padding(.leading, 52)
                                TransactionDetailRow(
                                    icon: "clock",
                                    title: "Created on",
                                    value: request.createdAt.formatted(date: .omitted, time: .shortened),
                                    color: .secondary
                                )
                            }
                            .background(Color.cardBackground)
                            .cornerRadius(AppRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        
                        // Optional Location Name
                        if let tx = originalTransaction, let locName = tx.locationName, !locName.isEmpty {
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                Text(locName)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, AppSpacing.margin)
                            .padding(.top, -AppSpacing.element)
                        }
                    
                    // 4. Actions
                    VStack(spacing: 16) {
                        if isIncoming {
                            // --- Receiver (User B) Actions ---
                            
                            if request.status == .pending {
                                // Accept Button — opens full transaction wizard
                                Button(action: {
                                    HapticManager.shared.medium()
                                    showAcceptWizard = true
                                }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Accept Request")
                                    }
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.blue)
                                    .cornerRadius(AppRadius.medium)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
                                }
                                
                                // Decline Button
                                Button(action: declineRequest) {
                                    Text("Decline Request")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.red)
                                }
                            } else if request.status == .accepted {
                                Text("Accepted - Waiting for settlement")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                            
                        } else if request.fromUid == appState.currentUserId {
                            // --- Sender (User A) Actions ---
                            
                            // Mark as Paid (Only Sender can do this now)
                            if request.status == .pending || request.status == .accepted {
                                let isEnabled = request.status == .accepted || request.isGuest == true
                                
                                Button(action: { HapticManager.shared.light(); 
                                    if isEnabled {
                                        markAsPaid()
                                    } else {
                                        HapticManager.shared.error()
                                        // Optional: Show alert or tooltip explaining why
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: isEnabled ? "banknote.fill" : "lock.fill")
                                        Text(isEnabled ? "Mark as Paid" : "Waiting for Acceptance")
                                    }
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(isEnabled ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(isEnabled ? AppColors.functionalIncome : Color.cardBackground)
                                    .cornerRadius(AppRadius.medium)
                                    .shadow(color: isEnabled ? AppColors.functionalIncome.opacity(0.3) : Color.clear, radius: 8, y: 4)
                                }
                                .disabled(!isEnabled)
                            }
                            
                            // Resend feature for Declined requests
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
                                    .cornerRadius(AppRadius.medium)
                                    .shadow(color: Color.blue.opacity(0.3), radius: 8, y: 4)
                                }
                            }
                            
                            // Allow canceling
                            if request.status == .pending || request.status == .declined || request.status == .accepted {
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
                                    .background(AppColors.functionalExpense.opacity(0.1))
                                    .clipShape(Capsule())
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
            loadAllSplits()
            userPremiumRepo.prefetch(userIds: [request.fromUid, request.toUid])
        }
        .sheet(isPresented: $showAcceptWizard) {
            AddTransactionView(requestToAccept: request, onSave: { transaction in
                // 1. Save the transaction
                Task {
                    do {
                        let amount = CurrencyInput.parseOrZero(transaction.amount)
                        let firestoreTransaction = FirestoreModels.TransactionModel(
                            userId: appState.currentUserId,
                            title: transaction.title,
                            categoryId: transaction.categoryId,
                            amount: amount,
                            date: transaction.date,
                            type: amount < 0 ? "expense" : "income",
                            createdAt: Date(),
                            note: transaction.notes,
                            latitude: transaction.latitude,
                            longitude: transaction.longitude,
                            locationName: transaction.locationName
                        )
                        try await appState.transactionRepo.addTransaction(firestoreTransaction)
                        
                        // 2. Update request status
                        try await appState.requestRepo.updateRequestStatus(
                            userId: appState.currentUserId,
                            requestId: request.id!,
                            status: .accepted,
                            lastUpdatedBy: appState.currentUserId
                        )
                        
                        await MainActor.run { dismiss() }
                    } catch {
                        await MainActor.run { errorState.show("Failed to accept request") }
                    }
                }
            })
        }
        .sheet(isPresented: $showFullMap) {
            if let tx = originalTransaction, let lat = tx.latitude, let lon = tx.longitude {
                FullScreenMapView(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), title: request.note ?? "Location")
            }
        }
    }

    private func loadOriginalTransaction() {
        let payerId = request.fromUid
        let txId = request.transactionId
        Task {
            do {
                originalTransaction = try await repo.fetchOriginalTransaction(userId: payerId, transactionId: txId)
            } catch {
                DebugLogger.log("Error loading original transaction for map: \(error)")
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
                    "createdAt": Date(), // Bump to top
                    "lastUpdatedBy": appState.currentUserId
                ])
                dismiss()
            } catch {
                errorState.show("Failed to resend request")
            }
        }
    }
    
    private func loadAllSplits() {
        Task {
            if let groupId = request.groupId {
                do {
                    allSplits = try await repo.fetchSplitsForTransaction(transactionId: request.transactionId, groupId: groupId)
                    userPremiumRepo.prefetch(userIds: allSplits.map { $0.toUid })
                } catch {
                    DebugLogger.log("Error loading splits: \(error)")
                }
            } else {
                allSplits = [request]
                userPremiumRepo.prefetch(userIds: [request.toUid])
            }
        }
    }
    
    private func markAsPaid() {
        HapticManager.shared.heavy()
        Task {
            do {
                _ = try await SocialTransactionManager.shared.markSplitAsPaid(
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
                try await appState.requestRepo.updateRequestStatus(userId: appState.currentUserId, requestId: request.id!, status: .declined, lastUpdatedBy: appState.currentUserId)
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
                // Use the new resolver to handle Delete (Payer) or Decline (Receiver)
                // Although this button is only shown for the Payer, it's safer to use the resolver.
                try await SocialTransactionManager.shared.resolveSplitRequestAction(request: request)
                dismiss()
            } catch {
                errorState.show("Failed to cancel request")
            }
        }
    }
    
    private func resolveName(uid: String, name: String?) -> String {
        return appState.userResolver.resolveName(for: uid, fallbackName: name)
    }
    
    private func splitStatusColor(_ status: FirestoreModels.SplitRequest.RequestStatus) -> Color {
        switch status {
        case .paid: return .green
        case .accepted: return .blue
        case .pending: return .orange
        case .declined: return .red
        default: return .gray
        }
    }
    
    private func splitStatusIcon(_ status: FirestoreModels.SplitRequest.RequestStatus) -> String {
        switch status {
        case .paid: return "checkmark.circle.fill"
        case .accepted: return "checkmark"
        case .pending: return "clock.fill"
        case .declined: return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }
    
    // toggleSplitPayment removed – Split Status card is now only shown on TransactionDetailView and GroupTransactionDetailView
}

// TransactionDetailRow is in Views/Components/TransactionDetailRow.swift
