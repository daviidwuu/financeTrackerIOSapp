import SwiftUI

struct RewardsView: View {
    @ObservedObject var manager: GamificationManager
    @StateObject private var rewardService = RewardService.shared
    @Environment(\.colorScheme) var colorScheme
    
    // Tab State: 0 = Marketplace, 1 = My Rewards
    @State private var selectedTab = 0
    @State private var selectedReward: FirestoreModels.Reward?
    @State private var showRedemptionAlert = false
    @State private var showResultAlert = false
    @State private var redemptionResultMessage = ""
    
    var body: some View {
        VStack(spacing: AppSpacing.margin) {
            // Segmented control
            Picker("Mode", selection: $selectedTab) {
                Text("Marketplace").tag(0)
                Text("My Rewards").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppSpacing.margin)
            
            if selectedTab == 0 {
                marketplaceTab
            } else {
                myRewardsTab
            }
        }
        .onAppear {
            rewardService.startListening(userRegion: "SG")
            if let userId = AppState.shared.currentUserId as String?, !userId.isEmpty {
                rewardService.loadRedemptions(userId: userId)
            }
        }
        .onDisappear {
            rewardService.stopListening()
        }
        .alert("Redeem Reward?", isPresented: $showRedemptionAlert) {
            Button("Redeem") {
                if let reward = selectedReward {
                    rewardService.redeemReward(reward, currentPoints: manager.points) { result in
                        if result.success {
                            // Deduct points on client
                            manager.points -= reward.cost
                            redemptionResultMessage = result.code != nil
                                ? "Your code: \(result.code!)\n\nCopy it and use it with \(reward.partnerName)."
                                : result.message
                        } else {
                            redemptionResultMessage = result.message
                        }
                        showResultAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will cost \(selectedReward?.cost ?? 0) points. You cannot undo this action.")
        }
        .alert("Redemption", isPresented: $showResultAlert) {
            Button("OK") {}
        } message: {
            Text(redemptionResultMessage)
        }
    }
    
    // MARK: - Marketplace Tab
    
    @ViewBuilder
    private var marketplaceTab: some View {
        if rewardService.isLoadingRewards {
            // Loading skeleton
            ScrollView {
                LazyVStack(spacing: AppSpacing.element) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(Color.cardBackground)
                            .frame(height: 90)
                            .shimmering()
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, 20)
            }
        } else if rewardService.rewards.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No Rewards Available")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text("There are no rewards available in your region yet. Check back soon!")
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
                    ForEach(rewardService.rewards) { reward in
                        RewardCard(
                            reward: reward,
                            canAfford: manager.points >= reward.cost,
                            isRedeeming: rewardService.isRedeeming
                        ) {
                            selectedReward = reward
                            showRedemptionAlert = true
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - My Rewards Tab
    
    @ViewBuilder
    private var myRewardsTab: some View {
        if rewardService.isLoadingRedemptions {
            ScrollView {
                LazyVStack(spacing: AppSpacing.element) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(Color.cardBackground)
                            .frame(height: 120)
                            .shimmering()
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, 20)
            }
        } else if rewardService.redemptions.isEmpty && manager.redemptions.isEmpty {
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
            let allRedemptions = mergedRedemptions()
            ScrollView {
                LazyVStack(spacing: AppSpacing.element) {
                    ForEach(allRedemptions) { redemption in
                        RedemptionCard(redemption: redemption)
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.bottom, 20)
            }
        }
    }
    
    /// Merge Firestore-loaded and local redemptions, deduplicating by ID.
    private func mergedRedemptions() -> [FirestoreModels.Redemption] {
        var seen = Set<String>()
        var merged: [FirestoreModels.Redemption] = []
        for r in rewardService.redemptions {
            if !seen.contains(r.id) {
                seen.insert(r.id)
                merged.append(r)
            }
        }
        for r in manager.redemptions {
            if !seen.contains(r.id) {
                seen.insert(r.id)
                merged.append(r)
            }
        }
        return merged.sorted { $0.date > $1.date }
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.2),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .onAppear {
                    withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = UIScreen.main.bounds.width
                    }
                }
            )
            .clipped()
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Reward Card

struct RewardCard: View {
    let reward: FirestoreModels.Reward
    let canAfford: Bool
    let isRedeeming: Bool
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
                HStack(spacing: 6) {
                    Text(reward.partnerName.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    
                    if let rewardType = reward.rewardType, rewardType == "paypal" {
                        Text("CASH")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#003087"))
                            .clipShape(Capsule())
                    }
                }
                
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
                HStack(spacing: 4) {
                    if isRedeeming {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(canAfford ? Color(UIColor.systemBackground) : .secondary)
                    Text("\(reward.cost)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(canAfford ? Color.primary : Color.secondary.opacity(0.2))
                .foregroundColor(canAfford ? Color(UIColor.systemBackground) : .secondary)
                .cornerRadius(AppRadius.small)
            }
            .disabled(!canAfford || isRedeeming)
        }
        .padding(AppSpacing.element)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
    }
}

// MARK: - Redemption Card

struct RedemptionCard: View {
    let redemption: FirestoreModels.Redemption
    @State private var showCopied = false
    
    private var statusColor: Color {
        switch redemption.status ?? "active" {
        case "active": return .green
        case "used": return .secondary
        case "expired": return .red
        default: return .secondary
        }
    }
    
    private var isExpired: Bool {
        if let expiresAt = redemption.expiresAt {
            return expiresAt < Date()
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Section
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(redemption.rewardTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Status badge
                        Text(isExpired ? "EXPIRED" : (redemption.status ?? "active").uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isExpired ? Color.red : statusColor)
                            .clipShape(Capsule())
                    }
                    
                    if let partnerName = redemption.partnerName {
                        Text(partnerName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 12) {
                        Text("Redeemed \(redemption.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let expiresAt = redemption.expiresAt, !isExpired {
                            Text("Expires \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
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
                    .foregroundColor(isExpired ? .secondary : .primary)
                    .strikethrough(isExpired)
                
                Spacer()
                
                if !isExpired {
                    Button(action: {
                        HapticManager.shared.light()
                        UIPasteboard.general.string = redemption.code
                        withAnimation { showCopied = true }
                        
                        // Clear clipboard after 60 seconds for security
                        let copiedCode = redemption.code
                        DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                            if UIPasteboard.general.string == copiedCode {
                                UIPasteboard.general.string = ""
                            }
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showCopied = false }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                            if showCopied {
                                Text("Copied!")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(showCopied ? .green : .blue)
                    }
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
