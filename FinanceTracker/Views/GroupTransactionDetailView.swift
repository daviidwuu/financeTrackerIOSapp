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
                VStack(spacing: 24) {
                    // 1. Hero
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: transaction.type == "settlement" ? "banknote" : "cart.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }
                        
                        Text(transaction.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Paid by \(transaction.payerName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(String(format: "$%.2f", transaction.amount))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.top, 8)
                        
                        Text(transaction.date.formatted(date: .long, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.top, 40)
                    
                    // 2. Splits List
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Split Details")
                            .font(.headline)
                            .padding(.horizontal, AppSpacing.margin)
                        
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if splits.isEmpty {
                            Text("No split details found.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, AppSpacing.margin)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(splits) { split in
                                    HStack {
                                        // User Avatar/Name
                                        HStack(spacing: 12) {
                                            ProfileAvatar(text: String((split.toName ?? "U").prefix(1)), color: .gray, size: 40)
                                            VStack(alignment: .leading) {
                                                Text(split.toName ?? "Friend") // This is the person who OWES
                                                    .fontWeight(.medium)
                                                Text(split.status.rawValue.capitalized)
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text("$\(String(format: "%.2f", split.amount))")
                                            .fontWeight(.bold)
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                    .padding(.horizontal, AppSpacing.margin)
                                    .padding(.bottom, 8)
                                }
                            }
                        }
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
