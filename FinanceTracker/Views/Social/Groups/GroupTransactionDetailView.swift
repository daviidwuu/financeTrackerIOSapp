import SwiftUI
import MapKit
import FirebaseFirestore

struct GroupTransactionDetailView: View {
    let transaction: FirestoreModels.GroupTransaction
    let group: FirestoreModels.Group?
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var repo = SocialRepository()
    
    @State private var splits: [FirestoreModels.SplitRequest] = []
    @State private var originalTransaction: FirestoreModels.TransactionModel?
    @State private var isLoading = true
    @State private var showHistory = false
    @State private var showingEditWizard = false
    @State private var selectedSplit: FirestoreModels.SplitRequest?
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Slim Header (nav bar + title only)
                DetailHeaderView(
                    title: "",
                    subtitle: nil as String?,
                    onBack: { dismiss() },
                    backIcon: "xmark",
                    onMenu: { showingEditWizard = true },
                    backgroundColor: Color.backgroundPrimary,
                    textColor: .primary,
                    height: AppSize.headerHeightSlim,
                    avatar: { EmptyView() },
                    actions: { EmptyView() }
                )
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Section: Icon, Amount, Date, Paid by
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: transaction.colorHex ?? "#007AFF").opacity(0.15))
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color(hex: transaction.colorHex ?? "#007AFF").opacity(0.2), radius: 15, y: 8)
                                
                                Image(systemName: transaction.type == "settlement" ? "banknote.fill" : (transaction.icon ?? "cart.fill"))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(hex: transaction.colorHex ?? "#007AFF"))
                            }
                            
                            Text(transaction.note?.isEmpty == false ? transaction.note! : transaction.title)
                                .font(AppTypography.titleDisplay)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text(transaction.category ?? "Uncategorized")
                                .font(AppTypography.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Text(String(format: "$%.2f", abs(transaction.amount)))
                                .font(AppTypography.prominentBalance)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 4) {
                                Text("Paid by")
                                    .foregroundColor(.secondary)
                                Text(transaction.payerId == appState.currentUserId ? "You" : transaction.payerName)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .font(.caption)
                            
                            HStack(spacing: 4) {
                                Text(transaction.date.formatted(date: .long, time: .shortened))
                                if let history = transaction.editHistory, !history.isEmpty {
                                    Button {
                                        showHistory = true
                                    } label: {
                                        Text("(Edited)")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            .underline()
                                    }
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.element)
                        
                        // 2. Split Breakdown
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SPLIT STATUS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.medium)
                            } else if splits.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("No split details available")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.medium)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(splits) { split in
                                        Button(action: {
                                            if split.toUid == appState.currentUserId || transaction.payerId == appState.currentUserId {
                                                selectedSplit = split
                                            }
                                        }) {
                                            HStack(spacing: 12) {
                                                // Mini Avatar
                                                ZStack {
                                                    Circle()
                                                        .fill(Color.primary.opacity(0.05))
                                                        .frame(width: 36, height: 36)
                                                    Text(String((split.toName ?? "").prefix(1)).uppercased())
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(.primary)
                                                }
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(split.toName ?? "Friend")
                                                        .font(.body)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.primary)
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 2) {
                                                    Text(String(format: "$%.2f", split.amount))
                                                        .font(.body.monospacedDigit())
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.primary)
                                                    
                                                    if let status = Optional(split.status) {
                                                        Text(status.rawValue.capitalized)
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                            .foregroundColor(statusColor(for: status))
                                                    }
                                                }
                                                
                                                // Inline Paid Toggle
                                                if transaction.payerId == appState.currentUserId {
                                                    Button(action: { toggleSplitPayment(split) }) {
                                                        Image(systemName: split.status == .paid ? "checkmark.circle.fill" : "circle")
                                                            .font(.title3)
                                                            .foregroundColor(split.status == .paid ? .green : .secondary.opacity(0.3))
                                                    }
                                                    
                                                } else if split.toUid == appState.currentUserId {
                                                     // Current User's Split (Friend View)
                                                    Button(action: { selectedSplit = split }) {
                                                        Image(systemName: "chevron.right")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 14)
                                            .padding(.horizontal, 16)
                                        }
                                        
                                        
                                        if split.id != splits.last?.id {
                                            Divider().padding(.horizontal, 16)
                                        }
                                    }
                                    
                                    // Net Cost Row (Only visible to Payer)
                                    if transaction.payerId == appState.currentUserId {
                                        // Divider handled by last element check above? No, we need one before Net Cost
                                        if !splits.isEmpty {
                                            Divider().padding(.horizontal, 16)
                                        }
                                        
                                        HStack {
                                            Text("Net Cost")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            let reimbursed = splits.filter { $0.status == .paid }.reduce(0) { $0 + $1.amount }
                                            Text(String(format: "$%.2f", abs(transaction.amount) - reimbursed))
                                                .font(.headline.monospacedDigit())
                                                .foregroundColor(.primary)
                                        }
                                        .padding(AppSpacing.element)
                                        .background(Color.primary.opacity(0.03))
                                    }
                                }
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(AppRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
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
                                // Map Header (Integrated into card)
                                if let tx = originalTransaction, let lat = tx.latitude, let long = tx.longitude {
                                    Map(initialPosition: .camera(MapCamera(centerCoordinate: CLLocationCoordinate2D(latitude: lat, longitude: long), distance: 500))) {
                                        Marker(transaction.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: long))
                                    }
                                    .frame(height: 140)
                                    
                                    Divider()
                                }
                                
                                // Total Amount
                                TransactionDetailRow(icon: "banknote", title: "Total Amount", value: String(format: "$%.2f", abs(transaction.amount)), color: .primary)
                                
                                // Your Share
                                let myShare = splits.first(where: { $0.toUid == appState.currentUserId })?.amount
                                    ?? (transaction.payerId == appState.currentUserId ? abs(transaction.amount) - splits.reduce(0) { $0 + $1.amount } : nil)
                                if let share = myShare {
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(icon: "person.crop.circle", title: "Your Share", value: String(format: "$%.2f", share), color: .blue)
                                }
                                
                                if let originalTx = originalTransaction,
                                   let originalAmount = originalTx.originalAmount,
                                   let currencyCode = originalTx.currencyCode {
                                    
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(icon: "banknote", title: "Original Amount", value: String(format: "%.2f %@", originalAmount, currencyCode), color: .blue)
                                    
                                    if let rate = originalTx.exchangeRate {
                                        Divider().padding(.leading, 52)
                                        TransactionDetailRow(icon: "arrow.triangle.2.circlepath", title: "Exchange Rate", value: String(format: "1 %@ = %.2f %@", transaction.currencyCode ?? CurrencyManager.shared.mainCurrency, rate, currencyCode), color: .orange)
                                    }
                                } else if let originalAmount = transaction.originalAmount, let rate = transaction.exchangeRate {
                                    // Fallback using data from GroupTransaction
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(icon: "banknote", title: "Original Amount", value: String(format: "%.2f (Foreign)", originalAmount), color: .blue)
                                     
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(icon: "arrow.triangle.2.circlepath", title: "Exchange Rate", value: String(format: "Rate: %.2f", rate), color: .orange)
                                }
                                
                                if let note = transaction.note, !note.isEmpty {
                                    Divider().padding(.leading, 52)
                                    TransactionDetailRow(icon: "text.alignleft", title: "Notes", value: note, color: .secondary)
                                }
                                
                                Divider().padding(.leading, 52)
                                TransactionDetailRow(icon: "clock", title: "Created on", value: transaction.date.formatted(date: .omitted, time: .shortened), color: .secondary)
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(AppRadius.medium)
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
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadSplits()
            loadOriginalTransaction()
        }
        .sheet(isPresented: $showingEditWizard) {
            EditGroupTransactionWizardView(group: group, preSelectedFriend: nil, transactionToEdit: transaction) { newAmount, newNote, newCategory, newSplits in
                handleEdit(amount: newAmount, note: newNote, category: newCategory, splits: newSplits)
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationView {
                List(transaction.editHistory ?? []) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(record.field.capitalized) Changed")
                            .font(.headline)
                        HStack {
                            Text(record.oldValue)
                                .strikethrough()
                                .foregroundColor(.red)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                            Text(record.newValue)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .font(.subheadline)
                        
                        Text("by \(record.editorName) on \(record.date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .navigationTitle("Edit History")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showHistory = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedSplit, onDismiss: { loadSplits() }) { split in
            SplitRequestDetailView(request: split)
        }
    }
    
    // MARK: - Handlers
    
    private func handleEdit(amount: Double, note: String, category: FirestoreModels.CategoryBudget?, splits: [FirestoreModels.Split]) {
        guard let originalTx = originalTransaction else { return }
        
        Task {
            do {
                // Update local model
                var updatedTx = originalTx
                updatedTx.amount = -abs(amount) // Ensure negative for expense
                updatedTx.splits = splits
                updatedTx.note = note.isEmpty ? nil : note
                updatedTx.title = note.isEmpty ? updatedTx.title : note // Update title if note is used as title logic
                
                // Update category if provided
                if let cat = category {
                    updatedTx.subtitle = cat.category
                    updatedTx.icon = cat.icon
                    updatedTx.colorHex = cat.colorHex
                }
                
                // Save to backend
                _ = try await SocialTransactionManager.shared.createSocialTransaction(
                    transaction: updatedTx,
                    payerUid: transaction.payerId, // Use GroupTransaction properties
                    payerName: transaction.payerName,
                    groupId: group?.id,
                    friendCache: appState.friendRepo.friends,
                    groupCache: appState.groupRepo.groups
                )
                
                await MainActor.run {
                    loadSplits()
                    loadOriginalTransaction()
                    HapticManager.shared.success()
                }
            } catch {
                print("Error updating transaction: \(error)")
                HapticManager.shared.error()
            }
        }
    }
    
    private func statusColor(for status: FirestoreModels.SplitRequest.RequestStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .blue
        case .declined: return .red
        case .paid: return .green
        case .blocked_by_group: return .secondary
        default: return .gray
        }
    }
    
    private func loadSplits() {
        // Use originalTransactionId first, fallback to group transaction's own ID
        guard let queryId = transaction.originalTransactionId ?? transaction.id else {
            isLoading = false
            return
        }
        Task {
            do {
                splits = try await repo.fetchSplitsForTransaction(transactionId: queryId)
            } catch {
                print("Error loading splits: \(error)")
            }
            isLoading = false
        }
    }

    private func loadOriginalTransaction() {
        guard let originalId = transaction.originalTransactionId else { return }
        let payerId = transaction.payerId
        Task {
            do {
                originalTransaction = try await repo.fetchOriginalTransaction(userId: payerId, transactionId: originalId)
            } catch {
                print("Error loading original transaction: \(error)")
            }
        }
    }
    
    // MARK: - Nudge Logic
    private func isNudgedRecently(_ split: FirestoreModels.SplitRequest) -> Bool {
        guard let lastNudged = split.lastNudgedAt else { return false }
        // Disable if nudged within last 24 hours
        return Date().timeIntervalSince(lastNudged) < 24 * 60 * 60
    }
    
    private func nudgeUser(split: FirestoreModels.SplitRequest) {
        // Optimistic Update
        let originalDate = split.lastNudgedAt
        if let index = splits.firstIndex(where: { $0.id == split.id }) {
            splits[index].lastNudgedAt = Date()
        }
        
        Task {
            do {
                try await SocialTransactionManager.shared.nudgeSplitRequest(request: split)
            } catch {
                print("Error nudging user: \(error)")
                // Revert if failed
                if let index = splits.firstIndex(where: { $0.id == split.id }) {
                    splits[index].lastNudgedAt = originalDate
                }
            }
        }
    }
    
    private func toggleSplitPayment(_ split: FirestoreModels.SplitRequest) {
        // Optimistic UI toggle
        if let index = splits.firstIndex(where: { $0.id == split.id }) {
            splits[index].status = (splits[index].status == .paid) ? .pending : .paid
        }
        
        Task {
            do {
                let currentStatus = split.status
                if currentStatus == .pending || currentStatus == .accepted || currentStatus == .blocked_by_group || currentStatus == .declined {
                     try await SocialTransactionManager.shared.markSplitAsPaid(request: split, currentUserId: appState.currentUserId, currentUserName: appState.userName)
                } else if currentStatus == .paid {
                     try await SocialTransactionManager.shared.unmarkSplitAsPaid(request: split, currentUserId: appState.currentUserId)
                }
                
                // Refresh to ensure sync
                loadSplits()
            } catch {
                print("Error toggling split payment: \(error)")
                // Revert UI
                await MainActor.run {
                    loadSplits()
                }
            }
        }
    }
}

// TransactionDetailRow is in Views/Components/TransactionDetailRow.swift
