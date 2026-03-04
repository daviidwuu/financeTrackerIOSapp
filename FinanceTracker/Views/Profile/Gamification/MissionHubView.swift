import SwiftUI

struct MissionHubView: View {
    @StateObject private var manager = GamificationManager.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedMission: GamificationManager.Mission?
    @State private var viewMode = 0 // 0 = Journey, 1 = Rewards

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.section) {
                        ScrollOffsetTracker()
                        Spacer().frame(height: 60)

                        // Points & Phase Header
                        VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(0.05))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.primary)
                                }
                                
                                Text("\(manager.points) Points")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "flag.fill")
                                        .font(.caption2)
                                    Text("Phase \(manager.currentPhase): \(getPhaseTitle(manager.currentPhase))")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(Capsule())
                            }
                            .padding(.top, 20)
                            
                            // Tab Switching
                            Picker("View Mode", selection: $viewMode) {
                                Text("Journey").tag(0)
                                Text("Rewards").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, AppSpacing.margin)
                            
                            if viewMode == 0 {
                                // Mission List
                                LazyVStack(spacing: AppSpacing.margin) {
                                    // Current Phase
                                    missionSection(phase: manager.currentPhase, isLocked: false)
                                    
                                    // Future Phases
                                    if manager.currentPhase < 4 {
                                        ForEach((manager.currentPhase + 1)...4, id: \.self) { phase in
                                            missionSection(phase: phase, isLocked: true)
                                        }
                                    }
                                    
                                    // Past Phases
                                    if manager.currentPhase > 1 {
                                        ForEach(1..<manager.currentPhase, id: \.self) { phase in
                                            missionSection(phase: phase, isLocked: false)
                                        }
                                    }
                                }
                                .padding(.horizontal, AppSpacing.margin)
                                .padding(.bottom, 40)
                            } else {
                                // Rewards View
                                RewardsView(manager: manager)
                                    .padding(.bottom, 40)
                            }
                        }
                    }
                }
            .overlayHeader(.navigation(title: "Your Journey", onBack: { dismiss() }, backIcon: "xmark"))
            .sheet(item: $selectedMission) { mission in
                MissionDetailView(mission: mission) {
                    handleMissionAction(mission)
                }
            }
            .overlay(
                ZStack {
                    if manager.showCelebration {
                        ConfettiView()
                            .allowsHitTesting(false)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    manager.showCelebration = false
                                }
                            }
                    }
                }
            )
        }
    }
    
    private func handleMissionAction(_ mission: GamificationManager.Mission) {
        dismiss()
        guard let link = mission.actionLink else { return }
        NotificationCenter.default.post(name: NSNotification.Name("HandleDeepLink"), object: nil, userInfo: ["link": link])
    }
    
    private func getPhaseTitle(_ phase: Int) -> String {
        switch phase {
        case 1: return "The Basics"
        case 2: return "Building Habits"
        case 3: return "Power Features"
        case 4: return "Social & Global"
        default: return "Master"
        }
    }
    
    @ViewBuilder
    private func missionSection(phase: Int, isLocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.element) {
            HStack {
                Text(getPhaseTitle(phase))
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                } else if phase < manager.currentPhase {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.primary)
                }
            }
            .padding(.bottom, 4)
            
            let missions = manager.getMissions(forPhase: phase)
            
            ForEach(missions) { mission in
                Button(action: {
                    HapticManager.shared.light()
                    selectedMission = mission
                }) {
                    MissionRow(mission: mission, isCompleted: manager.completedMissionIds.contains(mission.id), isLocked: isLocked)
                }
                
                .disabled(isLocked)
            }
        }
        .padding(AppSpacing.margin)
        .background(Color.cardBackground)
        .cornerRadius(AppRadius.medium)
        .opacity(isLocked ? 0.6 : 1.0)
    }
}

struct MissionRow: View {
    let mission: GamificationManager.Mission
    let isCompleted: Bool
    let isLocked: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 48, height: 48)
                
                Image(systemName: isCompleted ? "checkmark" : mission.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(mission.title)
                    .font(.headline)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .lineLimit(1)
                
                Text(mission.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if !isCompleted && !isLocked {
                Text("\(mission.points) pts")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.1))
                    .foregroundColor(.primary)
                    .clipShape(Capsule()) // Standardized to Capsule
            }
        }
        .padding(.vertical, 4)
    }
}


