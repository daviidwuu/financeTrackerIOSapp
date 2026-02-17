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
                // 1. Standard Header
                DetailHeaderView(
                    title: transaction.note?.isEmpty == false ? transaction.note! : transaction.title,
                    onBack: { dismiss() },
                    backIcon: "xmark",
                    onMenu: { showingEditWizard = true },
                    backgroundColor: Color.backgroundPrimary,
                    textColor: .primary,
                    avatar: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: transaction.colorHex ?? "#007AFF").opacity(0.15))
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(hex: transaction.colorHex ?? "#007AFF").opacity(0.2), radius: 15, y: 8)
                            
                            Image(systemName: transaction.type == "settlement" ? "banknote.fill" : (transaction.icon ?? "cart.fill"))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color(hex: transaction.colorHex ?? "#007AFF"))
                        }
                    },
                    subtitle: {
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
                    },
                    actions: {
                        VStack(spacing: 4) {
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
                        }
                    }
                )
                
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: AppSpacing.element)
                        
                        // 2. Split Breakdown
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SPLIT BREAKDOWN")
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
                                    // Payer Row
                                    let payerShare = abs(transaction.amount) - splits.reduce(0) { $0 + $1.amount }
                                    let payerName = transaction.payerId == appState.currentUserId ? "You" : transaction.payerName
                                    
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.random(seed: payerName))
                                                .frame(width: 36, height: 36)
                                            Text(String(payerName.prefix(1)).uppercased())
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(payerName)
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            Text("Payer")
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(String(format: "$%.2f", payerShare))
                                                .font(.body.monospacedDigit())
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            Text("Paid $\(String(format: "%.2f", abs(transaction.amount)))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    
                                    Divider().padding(.horizontal, 16)
                                    
                                    ForEach(splits) { split in
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
                                                
                                                // Status Text (Matching TransactionDetailView)
                                                if let status = Optional(split.status) {
                                                    Text(status.rawValue.capitalized)
                                                        .font(.caption2)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(statusColor(for: status))
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text(String(format: "$%.2f", split.amount))
                                                    .font(.body.monospacedDigit())
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)
                                                
                                                // Nudge Button (Only if pending)
                                                if transaction.payerId == appState.currentUserId && (split.status == .pending || split.status == .accepted) {
                                                    Button {
                                                        HapticManager.shared.light()
                                                        nudgeUser(split: split)
                                                    } label: {
                                                        Label("Nudge", systemImage: "bell.fill")
                                                            .font(.caption2)
                                                            .foregroundColor(.orange)
                                                    }
                                                    .disabled(isNudgedRecently(split))
                                                    .opacity(isNudgedRecently(split) ? 0.5 : 1.0)
                                                }
                                            }
                                                
                                            // Inline Paid Toggle (Only if user is owner OR it is their own split)
                                            if transaction.payerId == appState.currentUserId {
                                                Button(action: { toggleSplitPayment(split) }) {
                                                    Image(systemName: split.status == .paid ? "checkmark.circle.fill" : "circle")
                                                        .font(.title3)
                                                        .foregroundColor(split.status == .paid ? .green : .secondary.opacity(0.3))
                                                }
                                                .buttonStyle(.plain)
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
                                        .background(Color(UIColor.secondarySystemBackground))
                                        .contentShape(Rectangle()) // Make full row tappable
                                        .onTapGesture {
                                            // Only allow navigation if it's your own split or you are the payer (for details)
                                            if split.toUid == appState.currentUserId || transaction.payerId == appState.currentUserId {
                                                selectedSplit = split
                                            }
                                        }
                                        
                                        if split.id != splits.last?.id {
                                            Divider().padding(.horizontal, 16)
                                        }
                                    }
                                    
                                    // Net Cost Row (Only visible to Payer)
                                    if transaction.payerId == appState.currentUserId {
                                        Divider().padding(.horizontal, 16)
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
                                        .padding(16)
                                        .background(Color.primary.opacity(0.03))
                                    }
                                }
                                .cornerRadius(AppRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        
                        // 3. Details Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("DETAILS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            VStack(spacing: 0) {
                                GroupDetailRow(title: "Category", value: transaction.category ?? "Uncategorized", icon: "tag.fill", color: Color(hex: transaction.colorHex ?? "#808080"))
                                
                                if let originalTx = originalTransaction,
                                   let originalAmount = originalTx.originalAmount,
                                   let currencyCode = originalTx.currencyCode {
                                    
                                    Divider().padding(.leading, 52)
                                    GroupDetailRow(title: "Original Amount", value: String(format: "%.2f %@", originalAmount, currencyCode), icon: "banknote", color: .blue)
                                    
                                    if let rate = originalTx.exchangeRate {
                                        Divider().padding(.leading, 52)
                                        GroupDetailRow(title: "Exchange Rate", value: String(format: "1 %@ = %.2f %@", transaction.currencyCode ?? CurrencyManager.shared.mainCurrency, rate, currencyCode), icon: "arrow.triangle.2.circlepath", color: .orange)
                                    }
                                } else if let originalAmount = transaction.originalAmount, let rate = transaction.exchangeRate {
                                    // Fallback using data from GroupTransaction if OriginalTransaction isn't loaded yet (though code is missing)
                                    Divider().padding(.leading, 52)
                                    GroupDetailRow(title: "Original Amount", value: String(format: "%.2f (Foreign)", originalAmount), icon: "banknote", color: .blue)
                                     
                                    Divider().padding(.leading, 52)
                                    GroupDetailRow(title: "Exchange Rate", value: String(format: "Rate: %.2f", rate), icon: "arrow.triangle.2.circlepath", color: .orange)
                                }
                                
                                if let note = transaction.note, !note.isEmpty {
                                    Divider().padding(.leading, 52)
                                    GroupDetailRow(title: "Notes", value: note, icon: "text.alignleft", color: .secondary)
                                }
                                
                                Divider().padding(.leading, 52)
                                GroupDetailRow(title: "Created on", value: transaction.date.formatted(date: .omitted, time: .shortened), icon: "clock", color: .secondary)
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(AppRadius.medium)
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        
                        // 4. Map (If available)
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
                                .mapStyle(.standard)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                                
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
        guard let originalId = transaction.originalTransactionId else { return }
        Task {
            do {
                splits = try await repo.fetchSplitsForTransaction(transactionId: originalId)
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

private struct GroupDetailRow: View {
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
