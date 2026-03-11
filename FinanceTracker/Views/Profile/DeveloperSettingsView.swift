import SwiftUI

/// Temporary Developer Settings view for running the one-off data migration.
/// Access: Tap the version number in Profile 5 times.
/// Remove this view after migration is complete.
struct DeveloperSettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var isMigrating = false
    @State private var migrationResult: DataMigrationManager.MigrationResult?
    @State private var showResultAlert = false
    @State private var isProcessingPremium = false
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 80)
                    
                    VStack(spacing: AppSpacing.section) {
                        // Warning Banner
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Developer Tools")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("These actions modify your database. Use with caution.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(AppRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, AppSpacing.margin)
                        
                        // Premium Testing
                        MenuSection("Premium Features") {
                            Button(action: togglePremium) {
                                HStack {
                                    MenuRowView(
                                        icon: "crown.fill",
                                        title: appState.isPremiumUser ? "Revoke Premium" : "Grant Premium Instantly",
                                        value: appState.isPremiumUser ? "Active" : "Tap to grant"
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isProcessingPremium)
                            
                            if isProcessingPremium {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                    Text("Processing...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, AppSpacing.margin)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Migration Button
                        MenuSection("Data Migration") {
                            Button(action: runMigration) {
                                HStack {
                                    MenuRowView(
                                        icon: "arrow.triangle.2.circlepath",
                                        title: "Run Data Normalization",
                                        value: isMigrating ? "Running..." : "Tap to start"
                                    )
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(isMigrating)
                            
                            if isMigrating {
                                HStack {
                                    ProgressView()
                                        .padding(.trailing, 8)
                                    Text("Migrating... Do not close the app.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, AppSpacing.margin)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Results
                        if let result = migrationResult {
                            MenuSection("Last Migration Result") {
                                VStack(alignment: .leading, spacing: 8) {
                                    resultRow("Transactions migrated", value: "\(result.transactionsMigrated)")
                                    resultRow("Transactions skipped", value: "\(result.transactionsSkipped)")
                                    Divider()
                                    resultRow("Split Requests migrated", value: "\(result.splitRequestsMigrated)")
                                    resultRow("Split Requests skipped", value: "\(result.splitRequestsSkipped)")
                                    Divider()
                                    resultRow("Group Txs migrated", value: "\(result.groupTransactionsMigrated)")
                                    resultRow("Group Txs skipped", value: "\(result.groupTransactionsSkipped)")
                                    
                                    if !result.errors.isEmpty {
                                        Divider()
                                        Text("Errors (\(result.errors.count)):")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.red)
                                        ForEach(result.errors, id: \.self) { error in
                                            Text(error)
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                        }
                                    }
                                }
                                .padding(AppSpacing.element)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .overlayHeader(.navigation(title: "Developer", onBack: { dismiss() }))
        .navigationBarHidden(true)
        .alert("Migration Complete", isPresented: $showResultAlert) {
            Button("OK", role: .cancel) { HapticManager.shared.light(); }
        } message: {
            if let result = migrationResult {
                Text(result.summary)
            }
        }
    }
    
    private func resultRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
    
    private func togglePremium() {
        guard !isProcessingPremium else { return }
        isProcessingPremium = true
        HapticManager.shared.medium()
        
        let newValue = !appState.isPremiumUser
        
        Task {
            // Update local state first for immediate UI feedback
            await MainActor.run {
                appState.isPremiumUser = newValue
                appState.userPremiumRepo.setPremium(userId: appState.currentUserId, isPremium: newValue)
            }
            
            let userId = appState.currentUserId
            if !userId.isEmpty {
                do {
                    try await FirebaseManager.shared.updateUserProfile(userId: userId, data: ["isPremium": newValue])
                } catch {
                    DebugLogger.log("Failed to update premium status in Firebase: \(error)")
                }
            }
            
            await MainActor.run {
                self.isProcessingPremium = false
                HapticManager.shared.success()
            }
        }
    }
    
    private func runMigration() {
        guard !isMigrating else { return }
        isMigrating = true
        HapticManager.shared.medium()
        
        Task {
            let manager = DataMigrationManager()
            let result = await manager.runFullMigration(
                userId: appState.currentUserId,
                categories: appState.budgetRepo.budgets
            )
            
            await MainActor.run {
                self.migrationResult = result
                self.isMigrating = false
                self.showResultAlert = true
                
                if result.errors.isEmpty {
                    HapticManager.shared.success()
                } else {
                    HapticManager.shared.error()
                }
            }
        }
    }
}

#Preview {
    DeveloperSettingsView()
}
