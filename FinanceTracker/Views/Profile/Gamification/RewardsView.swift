import SwiftUI

struct RewardsView: View {
    @ObservedObject var manager: GamificationManager
    @Environment(\.colorScheme) var colorScheme
    
    // Tab State: 0 = Marketplace, 1 = My Rewards
    @State private var selectedTab = 0
    @State private var selectedReward: FirestoreModels.Reward?
    @State private var showRedemptionAlert = false
    
    var body: some View {
        VStack(spacing: AppSpacing.margin) {
            // segmented control
            Picker("Mode", selection: $selectedTab) {
                Text("Marketplace").tag(0)
                Text("My Rewards").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.margin)
            
            if selectedTab == 0 {
                // Marketplace
                ScrollView {
                    LazyVStack(spacing: AppSpacing.element) {
                        ForEach(manager.availableRewards) { reward in
                            RewardCard(reward: reward, canAfford: manager.points >= reward.cost) {
                                selectedReward = reward
                                showRedemptionAlert = true
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.bottom, 20)
                }
            } else {
                // My Rewards
                if manager.redemptions.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Rewards Yet")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("Redeem your points in the Marketplace to get exclusive partner deals.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                    }
                    .padding(.top, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.element) {
                            ForEach(manager.redemptions) { redemption in
                                RedemptionCard(redemption: redemption)
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .alert(isPresented: $showRedemptionAlert) {
            Alert(
                title: Text("Redeem Reward?"),
                message: Text("This will cost \(selectedReward?.cost ?? 0) points. You cannot undo this action."),
                primaryButton: .default(Text("Redeem")) {
                    if let reward = selectedReward {
                        manager.redeem(reward: reward)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct RewardCard: View {
    let reward: FirestoreModels.Reward
    let canAfford: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(Color(hex: reward.colorHex).opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: reward.icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: reward.colorHex))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(reward.partnerName.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Text(reward.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(reward.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: action) {
                Text("\(reward.cost)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(canAfford ? Color.primary : Color.secondary.opacity(0.2))
                    .foregroundColor(canAfford ? Color(UIColor.systemBackground) : .secondary)
                    .cornerRadius(AppRadius.small)
            }
            .disabled(!canAfford)
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }
}

struct RedemptionCard: View {
    let redemption: FirestoreModels.Redemption
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Section (Ticket stub style)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(redemption.rewardTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Redeemed on \(redemption.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: redemption.rewardIcon)
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground)
            
            Divider()
                .background(Color(UIColor.systemBackground))
            
            // Bottom Section (Code)
            HStack {
                Text("CODE:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                Text(redemption.code)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: { HapticManager.shared.light(); 
                    UIPasteboard.general.string = redemption.code
                    HapticManager.shared.light()
                    // Clear clipboard after 60 seconds for security
                    let copiedCode = redemption.code
                    DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                        if UIPasteboard.general.string == copiedCode {
                            UIPasteboard.general.string = ""
                        }
                    }
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(AppSpacing.element)
            .background(Color.cardBackground.opacity(0.5))
        }
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
