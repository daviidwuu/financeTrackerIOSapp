import SwiftUI

struct RewardsView: View {
    @ObservedObject var manager: GamificationManager
    @Environment(\.colorScheme) var colorScheme
    
    // Tab State: 0 = Marketplace, 1 = My Rewards
    @State private var selectedTab = 0
    @State private var selectedReward: FirestoreModels.Reward?
    @State private var showRedemptionAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            // segmented control
            Picker("Mode", selection: $selectedTab) {
                Text("Marketplace").tag(0)
                Text("My Rewards").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if selectedTab == 0 {
                // Marketplace
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(manager.availableRewards) { reward in
                            RewardCard(reward: reward, canAfford: manager.points >= reward.cost) {
                                selectedReward = reward
                                showRedemptionAlert = true
                            }
                        }
                    }
                    .padding()
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
                        LazyVStack(spacing: 16) {
                            ForEach(manager.redemptions) { redemption in
                                RedemptionCard(redemption: redemption)
                            }
                        }
                        .padding()
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
                RoundedRectangle(cornerRadius: 12)
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
                    .cornerRadius(16)
            }
            .disabled(!canAfford)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
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
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            
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
                
                Button(action: {
                    UIPasteboard.general.string = redemption.code
                    HapticManager.shared.light()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
        }
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
