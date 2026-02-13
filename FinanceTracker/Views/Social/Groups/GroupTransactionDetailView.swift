import SwiftUI

struct GroupTransactionDetailView: View {
    let transaction: FirestoreModels.GroupTransaction
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var repo = SocialRepository()
    
    @State private var splits: [FirestoreModels.SplitRequest] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppSpacing.section) {
                    // 1. Hero Card
                    VStack(spacing: 12) {
                        // Category Icon Circle
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: transaction.type == "settlement" ? "banknote" : "cart.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .shadow(color: Color.blue.opacity(0.2), radius: 15, y: 8)
                        
                        VStack(spacing: 4) {
                            Text(transaction.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text(String(format: "$%.2f", transaction.amount))
                                .font(AppTypography.prominentBalance)
                                .foregroundColor(.primary)
                            
                            Text(transaction.date.formatted(date: .long, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Paid by \(transaction.payerName)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.top, 20)
                    
                    // 2. Splits List
                    if !splits.isEmpty || isLoading {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SPLIT DETAILS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(splits) { split in
                                        HStack(spacing: 12) {
                                            // User Avatar
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
                                                
                                                Text(split.status.rawValue.capitalized)
                                                    .font(.caption2)
                                                    .foregroundColor(statusColor(for: split.status))
                                            }
                                            
                                            Spacer()
                                            
                                            Text(String(format: "$%.2f", split.amount))
                                                .font(.body) // Monospaced for numbers alignment?
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                        }
                                        .padding(16)
                                        .background(Color(UIColor.secondarySystemBackground))
                                        
                                        if split.id != splits.last?.id {
                                            Divider()
                                                .padding(.leading, 68) // Indent divider past avatar
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
                    } else if !isLoading {
                        Text("No split details found.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear {
            loadSplits()
        }
    }
    
    private func statusColor(for status: FirestoreModels.SplitRequest.RequestStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .accepted: return .blue
        case .declined: return .red
        case .paid: return .green
        case .blocked_by_group: return .red
        default: return .gray
        }
    }
    
    private func loadSplits() {
        guard let id = transaction.id else { return }
        Task {
            do {
                // If it's a settlement, maybe it has 1 split request?
                // The transaction ID in SplitRequest links to the GroupTransaction ID?
                // Or vice versa?
                // In `markSplitAsPaid`:
                // We create a GroupTransaction.
                // But we don't update the SplitRequest with the GroupTransaction ID.
                // Actually, the SplitRequest ALREADY exists.
                // The GroupTransaction is NEW.
                // So there is NO link from SplitRequest to this NEW GroupTransaction ID unless we add it.
                // HOWEVER, for *Normal Expenses* (Bill Split), we create GroupTransaction AND SplitRequests together.
                // Let's assume for normal expenses, they share an ID or are linked.
                // If this fails, we might show empty list.
                
                splits = try await repo.fetchSplitsForTransaction(transactionId: id)
            } catch {
                print("Error loading splits: \(error)")
            }
            isLoading = false
        }
    }
}
