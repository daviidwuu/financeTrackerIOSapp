import SwiftUI
import MapKit

struct GroupTransactionDetailView: View {
    let transaction: FirestoreModels.GroupTransaction
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var repo = SocialRepository()
    
    @State private var splits: [FirestoreModels.SplitRequest] = []
    @State private var originalTransaction: FirestoreModels.TransactionModel?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Custom Header & Hero
                    VStack(spacing: 0) {
                        // Nav Bar
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.top, 16)
                        
                        // Hero Content
                        VStack(spacing: 16) {
                            // Icon
                            ZStack {
                                Circle()
                                    .fill(Color(hex: transaction.colorHex ?? "#007AFF").opacity(0.15))
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color(hex: transaction.colorHex ?? "#007AFF").opacity(0.2), radius: 15, y: 8)
                                
                                Image(systemName: transaction.type == "settlement" ? "banknote.fill" : (transaction.icon ?? "cart.fill"))
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Color(hex: transaction.colorHex ?? "#007AFF"))
                            }
                            
                            VStack(spacing: 4) {
                                Text(transaction.note?.isEmpty == false ? transaction.note! : transaction.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 4) {
                                    Text(transaction.date.formatted(date: .long, time: .shortened))
                                    if let history = transaction.editHistory, !history.isEmpty {
                                        Text("(Edited)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                
                                Text(String(format: "$%.2f", abs(transaction.amount)))
                                    .font(AppTypography.prominentBalance)
                                    .foregroundColor(.primary)
                                    .padding(.top, 8)
                                
                                HStack(spacing: 4) {
                                    Text("Paid by")
                                        .foregroundColor(.secondary)
                                    Text(transaction.payerId == appState.currentUserId ? "You" : transaction.payerName)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                .font(.caption)
                                .padding(.top, 4)
                            }
                        }
                        .padding(.top, 10)
                    }
                    
                    // 2. Splits List
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
                                ForEach(splits) { split in
                                    HStack(spacing: 12) {
                                        ProfileAvatar(
                                            text: String((split.toName ?? "U").prefix(1)),
                                            color: Color.random(seed: split.toName ?? "User"),
                                            size: 40
                                        )
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(split.toName ?? "Friend")
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(.primary)
                                            
                                            // Status Badge Pill
                                            Text(split.status.rawValue.capitalized)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .foregroundColor(statusColor(for: split.status))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(statusColor(for: split.status).opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                        
                                        Spacer()
                                        
                                        Text(String(format: "$%.2f", split.amount))
                                            .font(.body)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(16)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    
                                    if split.id != splits.last?.id {
                                        Divider().padding(.leading, 68)
                                    }
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
                                if let category = transaction.category ?? originalTransaction?.subtitle {
                                    GroupDetailRow(title: "Category", value: category, icon: "tag.fill", color: .teal)
                                    Divider().padding(.leading, 52)
                                }
                                
                                let myShare = splits.first(where: { $0.toUid == appState.currentUserId })
                                if let share = myShare {
                                    GroupDetailRow(title: "Your Share", value: String(format: "$%.2f", share.amount), icon: "person.crop.circle", color: .mint)
                                    Divider().padding(.leading, 52)
                                }
                                
                                GroupDetailRow(title: "Split Between", value: "\(splits.count + 1) people", icon: "person.3.fill", color: .purple)
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
        .navigationBarHidden(true)
        .onAppear {
            loadSplits()
            loadOriginalTransaction()
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
        // Fix: Use originalTransactionId because splits are linked to the source transaction, not the group transaction ID
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


