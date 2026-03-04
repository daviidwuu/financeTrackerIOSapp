import SwiftUI

struct PremiumBadgeSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("premiumBadgeType") private var badgeType: PremiumBadgeType = .king
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 80)
                    
                    MenuSection("Badge Style") {
                        ForEach(Array(PremiumBadgeType.allCases.enumerated()), id: \.element) { index, type in
                            Button(action: {
                                HapticManager.shared.light()
                                badgeType = type
                            }) {
                                MenuControlRow(title: type.title.capitalized) {
                                    Text(type.title)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(type.color)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(type.color.opacity(0.15))
                                        .cornerRadius(12)
                                    
                                    if badgeType == type {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(Color.orange) // Brand color
                                            .padding(.leading, 8)
                                    } else {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.clear)
                                            .padding(.leading, 8)
                                    }
                                }
                            }
                            .buttonStyle(MenuRowButtonStyle())
                            
                            if index < PremiumBadgeType.allCases.count - 1 {
                                MenuDivider()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .overlayHeader(.navigation(title: "Badge Prefix", onBack: { dismiss() }))
        .navigationBarHidden(true)
    }
}
