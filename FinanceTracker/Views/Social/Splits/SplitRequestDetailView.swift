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
    private var counterpartyName: String {
        if isIncoming {
            return resolveName(uid: request.fromUid, name: request.fromName)
        }
        return resolveName(uid: request.toUid, name: request.toName)
    }
    private var presentation: RequestPresentation {
        request.presentation(for: appState.currentUserId, counterpartyName: counterpartyName)
    }
    private var displayCurrency: String { request.resolvedCurrency }
    private var displayCategoryName: String {
        if let category = request.category, !category.isEmpty {
            return category
        }
        if let id = originalTransaction?.categoryId,
           let category = appState.budgetRepo.getCategory(for: id) {
            return category.category
        }
        return "Split Expense"
    }
    private var formattedShareAmount: String {
        CurrencyFormatter.format(request.amount, currencyCode: displayCurrency)
    }
    private var formattedOriginalAmount: String {
        if let originalAmount = originalTransaction?.originalAmount,
           let currencyCode = originalTransaction?.currencyCode,
           !currencyCode.isEmpty {
            return CurrencyFormatter.format(originalAmount, currencyCode: currencyCode)
        }
        return CurrencyFormatter.format(
            request.originalTotalAmount ?? abs(originalTransaction?.amount ?? request.amount),
            currencyCode: displayCurrency
        )
    }

    private var statusColor: Color {
        switch request.status {
        case .pending: return .orange
        case .accepted: return .blue
        case .declined: return Color.functionalError
        case .paid: return Color.functionalSuccess
        case .blocked_by_group: return .secondary
        default: return .secondary
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
                    VStack(spacing: AppSpacing.large) {
                        // Hero Section: Icon, Amount, Status, Date
                        VStack(spacing: AppSpacing.compact) {
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
                            
                            Text(displayCategoryName)
                                .font(AppTypography.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text(formattedShareAmount)
                                .font(AppTypography.prominentBalance)
                                .foregroundColor(.primary)
                            
                            // Status Pill
                            Text(presentation.badge)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(statusColor)
                                .padding(.horizontal, AppSpacing.compact)
                                .padding(.vertical, AppRadius.xSmall)
                                .background(statusColor.opacity(0.1))
                                .clipShape(Capsule())
                            
                            Text(request.createdAt.formatted(date: .long, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.element)
                        
                        // 2. Split Status Section
                        VStack(alignment: .leading, spacing: AppSpacing.element) {
                            Text("SPLIT STATUS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 0) {
                                if allSplits.isEmpty {
                                    HStack(spacing: AppSpacing.compact) {
                                        ProgressView()
                                        Text("Loading split status")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, AppSpacing.element)
                                    .padding(.vertical, AppSpacing.element)
                                } else {
                                    ForEach(Array(allSplits.enumerated()), id: \.element.id) { index, split in
                                        HStack(spacing: AppSpacing.compact) {
                                            Circle()
                                                .fill(splitStatusColor(split.status).opacity(0.15))
                                                .frame(width: 36, height: 36)
                                                .overlay(
                                                    Image(systemName: splitStatusIcon(split.status))
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(splitStatusColor(split.status))
                                                )
                                            
                                            VStack(alignment: .leading, spacing: AppSpacing.micro) {
                                                HStack(spacing: AppSpacing.compact) {
                                                    Text(resolveName(uid: split.toUid, name: split.toName))
                                                        .font(.body)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.primary)
                                                    
                                                    if userPremiumRepo.isPremium(userId: split.toUid) == true {
                                                        PremiumBadge(size: .small, overrideBadgeType: userPremiumRepo.badgeType(userId: split.toUid))
                                                    }
                                                }

                                                Text(splitBadge(split))
                                                    .font(.caption)
                                                    .foregroundColor(splitStatusColor(split.status))
                                            }
                                            
                                            Spacer()
                                            
                                            Text(CurrencyFormatter.format(split.amount, currencyCode: split.resolvedCurrency))
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                        }
                                        .padding(.horizontal, AppSpacing.element)
                                        .padding(.vertical, AppSpacing.compact)
                                        
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
                        VStack(alignment: .leading, spacing: AppSpacing.element) {
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
                                    HStack(spacing: AppSpacing.compact) {
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
                                    HStack(spacing: AppSpacing.compact) {
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
                                TransactionDetailRow(icon: "tag", title: "Category", value: displayCategoryName, color: .primary)
                                
                                Divider().padding(.leading, 52)
                                TransactionDetailRow(
                                    icon: "banknote",
                                    title: "Original Amount",
                                    value: formattedOriginalAmount,
                                    color: .blue
                                )
                                
                                Divider().padding(.leading, 52)
                                TransactionDetailRow(
                                    icon: "person.crop.circle",
                                    title: "Your Share",
                                    value: formattedShareAmount,
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
                    VStack(spacing: AppSpacing.element) {
                        if let primaryAction = presentation.primaryAction {
                            detailActionButton(primaryAction)
                        }

                        if let secondaryAction = presentation.secondaryAction {
                            detailActionButton(secondaryAction)
                        }

                        if presentation.primaryAction == nil,
                           presentation.secondaryAction == nil,
                           let detailMessage = presentation.detailMessage {
                            Text(detailMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.top, AppSpacing.element)
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
                Task {
                    do {
                        let acceptedTransaction = transaction.firestoreModel(userId: appState.currentUserId)
                        _ = try await SocialTransactionManager.shared.acceptSplitRequest(
                            request: request,
                            acceptedTransaction: acceptedTransaction,
                            currentUserId: appState.currentUserId
                        )

                        NotificationManager.shared.sendTransactionNotification(
                            amount: acceptedTransaction.amount,
                            category: transaction.title,
                            type: transaction.type,
                            originalAmount: transaction.originalAmount,
                            currencyCode: transaction.currencyCode
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

    @ViewBuilder
    private func detailActionButton(_ action: RequestAction) -> some View {
        Button(action: {
            handleAction(action)
        }) {
            HStack {
                Image(systemName: action.iconName)
                Text(action.title)
            }
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(foregroundColor(for: action))
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.element)
            .background(backgroundColor(for: action))
            .cornerRadius(AppRadius.medium)
            .shadow(color: shadowColor(for: action), radius: 8, y: 4)
        }
    }

    private func handleAction(_ action: RequestAction) {
        switch action {
        case .acceptSplit:
            HapticManager.shared.medium()
            showAcceptWizard = true
        case .declineSplit:
            declineRequest()
        case .acceptSettlement:
            acceptSettlement()
        case .declineSettlement:
            declineSettlement()
        case .confirmPaymentReceived:
            markAsPaid()
        case .cancelRequest:
            cancelRequest()
        case .resendRequest:
            resendRequest()
        case .nudge:
            HapticManager.shared.medium()
            Task {
                do {
                    try await SocialTransactionManager.shared.nudgeSplitRequest(request: request)
                    HapticManager.shared.success()
                } catch {
                    await MainActor.run { HapticManager.shared.error() }
                }
            }
        }
    }

    private func foregroundColor(for action: RequestAction) -> Color {
        switch action.emphasis {
        case .primary:
            return .white
        case .secondary:
            return Color.functionalError
        case .destructive:
            return Color.functionalError
        }
    }

    private func backgroundColor(for action: RequestAction) -> Color {
        switch action {
        case .confirmPaymentReceived:
            return AppColors.functionalIncome
        case .cancelRequest:
            return AppColors.functionalExpense.opacity(0.1)
        case .declineSplit, .declineSettlement:
            return AppColors.functionalExpense.opacity(0.1)
        default:
            return AppColors.brandPrimary
        }
    }

    private func shadowColor(for action: RequestAction) -> Color {
        switch action {
        case .confirmPaymentReceived:
            return AppColors.functionalIncome.opacity(0.3)
        case .acceptSplit, .acceptSettlement, .resendRequest, .nudge:
            return AppColors.brandPrimary.opacity(0.3)
        default:
            return .clear
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

    private func acceptSettlement() {
        HapticManager.shared.success()
        Task {
            do {
                try await SocialTransactionManager.shared.acceptSettlement(
                    request: request,
                    currentUserId: appState.currentUserId,
                    currentUserName: appState.userName
                )
                dismiss()
            } catch {
                errorState.show("Failed to accept settlement")
            }
        }
    }

    private func declineSettlement() {
        HapticManager.shared.heavy()
        Task {
            do {
                try await SocialTransactionManager.shared.declineSettlement(request: request)
                dismiss()
            } catch {
                errorState.show("Failed to decline settlement")
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
        case .paid: return Color.functionalSuccess
        case .accepted: return .blue
        case .pending: return .orange
        case .declined: return Color.functionalError
        default: return .secondary
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

    private func splitBadge(_ split: FirestoreModels.SplitRequest) -> String {
        let name = resolveName(uid: split.fromUid == appState.currentUserId ? split.toUid : split.fromUid, name: split.fromUid == appState.currentUserId ? split.toName : split.fromName)
        return split.presentation(for: appState.currentUserId, counterpartyName: name).badge
    }
    
    // toggleSplitPayment removed – Split Status card is now only shown on TransactionDetailView and GroupTransactionDetailView
}

// TransactionDetailRow is in Views/Components/TransactionDetailRow.swift
