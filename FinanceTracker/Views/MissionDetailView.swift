import SwiftUI

struct MissionDetailView: View {
    let mission: GamificationManager.Mission
    let onAction: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: mission.icon)
                            .font(.system(size: 40))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)
                    
                    // Title & Description
                    VStack(spacing: 8) {
                        Text(mission.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(mission.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("+\(mission.points) Points")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Steps
                    VStack(alignment: .leading, spacing: 20) {
                        Text("How to Complete")
                            .font(.headline)
                            .padding(.bottom, 4)
                        
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
                    .padding(.horizontal)
                    .padding(.horizontal) // Extra padding for card look? No, standard padding.
                    
                    Spacer(minLength: 40)
                    
                    // Action Button
                    if let _ = mission.actionLink {
                        Button(action: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onAction()
                            }
                        }) {
                            Text("Go to Feature")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(Color(UIColor.systemBackground)) // Inverse of primary for text
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.primary)
                                .cornerRadius(AppRadius.button)
                        }
                        .padding(.horizontal, AppSpacing.margin)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.primary)
                }
            }
        }
    }
}
