import SwiftUI
import WidgetKit

struct PrivacySettingsView: View {
    @State private var faceIDEnabled = true
    @State private var analyticsEnabled = true
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)
                    
                    MenuSection("Security") {
                        MenuRowView(icon: "faceid", title: "Use Face ID", showChevron: false, showToggle: $faceIDEnabled, iconColor: .green)
                        MenuDivider()
                        NavigationLink {
                            Text("2FA Setup")
                                .navigationTitle("2FA")
                        } label: {
                            MenuRowView(icon: "lock.shield", title: "Two-Factor Authentication", iconColor: .blue)
                        }
                        
                    }
                    .padding(.top, 0)
                    
                    MenuSection("Data") {
                        MenuRowView(icon: "chart.bar.xaxis", title: "Share Analytics", showChevron: false, showToggle: $analyticsEnabled, iconColor: .orange)
                        MenuDivider()
                        NavigationLink {
                            Text("Privacy Policy Content")
                                .navigationTitle("Privacy Policy")
                        } label: {
                            MenuRowView(icon: "hand.raised.fill", title: "Data & Privacy Info", iconColor: .purple)
                        }
                        
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
        }
        .overlayHeader(.navigation(title: "Privacy & Security", onBack: { dismiss() }))
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Help Center
