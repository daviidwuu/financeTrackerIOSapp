import SwiftUI

struct MissionDetailView: View {
    let mission: GamificationManager.Mission
    let onAction: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showTutorial = false
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppSpacing.section) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)
                    
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: mission.icon)
                            .font(.system(size: 40))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 10)
                    
                    // Title & Description
                    VStack(spacing: AppSpacing.compact) {
                        Text(mission.title)
                            .font(AppTypography.sectionHeader)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                        
                        Text(mission.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text("+\(mission.points) Points")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                        .padding(.top, 8)
                    }
                    
                    Divider()
                        .padding(.horizontal, AppSpacing.margin)
                    
                    // Steps Preview
                    VStack(alignment: .leading, spacing: AppSpacing.element) {
                        Text("How to Complete")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(Array(mission.tutorialSteps.prefix(3).enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(step.iconColor.opacity(0.1))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: step.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(step.iconColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text(step.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                        }
                        
                        if mission.tutorialSteps.count > 3 {
                            Text("+\(mission.tutorialSteps.count - 3) more steps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 52)
                        }
                    }
                    .padding(.horizontal, AppSpacing.margin)
                    
                    Spacer(minLength: 40)
                    
                    // Tutorial Button
                    Button(action: {
                        HapticManager.shared.medium()
                        showTutorial = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                            Text("Start Tutorial")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, AppSpacing.margin)
                    .padding(.bottom, 20)
                }
            }
        }
        .overlayHeader(.navigation(
            title: mission.title,
            onBack: { dismiss() },
            backIcon: "xmark"
        ))
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialView(
                title: mission.title,
                steps: mission.tutorialSteps,
                accentColor: .primary,
                onComplete: {
                    // After tutorial completion, trigger the mission action
                    onAction()
                }
            )
        }
    }
}
