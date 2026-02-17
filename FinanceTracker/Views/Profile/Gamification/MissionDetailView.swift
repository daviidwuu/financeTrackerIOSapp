import SwiftUI

struct MissionDetailView: View {
    let mission: GamificationManager.Mission
    let onAction: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Spacer()
                    // Close Button
                    Button(action: {
                        HapticManager.shared.light()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, AppSpacing.margin)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                ScrollView {
                    VStack(spacing: AppSpacing.section) {
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
                        
                        // Steps
                        VStack(alignment: .leading, spacing: AppSpacing.element) {
                            Text("How to Complete")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ForEach(Array(mission.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 16) {
                                    Text("\(index + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .frame(width: 24, height: 24)
                                        .background(Color.secondary.opacity(0.2))
                                        .clipShape(Circle())
                                        .foregroundColor(.primary)
                                    
                                    Text(step)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        
                        Spacer(minLength: 40)
                        
                        // Action Button
                        if let _ = mission.actionLink {
                            Button(action: {
                                HapticManager.shared.medium()
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onAction()
                                }
                            }) {
                                Text("Go to Feature")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.horizontal, AppSpacing.margin)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .background(Color.backgroundPrimary)
        }
    }
}
