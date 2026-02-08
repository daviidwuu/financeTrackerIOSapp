import SwiftUI

struct MissionHubView: View {
    @StateObject private var manager = GamificationManager.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedMission: GamificationManager.Mission?
    @State private var viewMode = 0 // 0 = Journey, 1 = Rewards

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.backgroundPrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header / Current Level
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
                            
                            Text("Phase \(manager.currentPhase): \(getPhaseTitle(manager.currentPhase))")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        .padding(.top, 20)
                        
                        Divider()
                        
                        // Tab Switching
                        Picker("View Mode", selection: $viewMode) {
                            Text("Journey").tag(0)
                            Text("Rewards").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if viewMode == 0 {
                            // Mission List
                            LazyVStack(spacing: 20) {
                                // Current Phase
                                missionSection(phase: manager.currentPhase, isLocked: false)
                                
                                // Future Phases
                                if manager.currentPhase < 4 {
                                    ForEach((manager.currentPhase + 1)...4, id: \.self) { phase in
                                        missionSection(phase: phase, isLocked: true)
                                    }
                                }
                                
                                if manager.currentPhase > 1 {
                                    ForEach(1..<manager.currentPhase, id: \.self) { phase in
                                        missionSection(phase: phase, isLocked: false) // Already done
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                        } else {
                            // Rewards View
                            RewardsView(manager: manager)
                                .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("Your Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.primary)
                }
            }
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
        // Dismiss Mission Hub to let user navigate
        dismiss()
        
        // Post notification or trigger state change in AppState to navigate
        // For simplicity, we can print for now or assume user will navigate manually.
        // Ideally, we post a notification that HomeView or ContentView listens to.
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
        VStack(alignment: .leading, spacing: 16) {
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
            
            let missions = manager.getMissions(forPhase: phase)
            
            ForEach(missions) { mission in
                Button(action: {
                    HapticManager.shared.light()
                    selectedMission = mission
                }) {
                    MissionRow(mission: mission, isCompleted: manager.completedMissionIds.contains(mission.id), isLocked: isLocked)
                }
                .buttonStyle(.plain) // Standard button style for rows
                .disabled(isLocked)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
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
                
                Text(mission.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isCompleted && !isLocked {
                Text("\(mission.points) pts")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

// Simple Confetti Placeholder
struct ConfettiView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<50) { _ in
                    Circle()
                        .fill(Color.random)
                        .frame(width: 8, height: 8)
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }
            }
        }
    }
}

extension Color {
    static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}
