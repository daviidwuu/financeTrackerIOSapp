import SwiftUI
import WidgetKit

struct PrivacySettingsView: View {
    @State private var faceIDEnabled = true
    @State private var analyticsEnabled = true
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            (colorScheme == .dark ? Color.black : Color(UIColor.systemBackground))
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 60)
                    
                    MenuSection("Security") {
                        MenuRowView(icon: "faceid", title: "Use Face ID", showChevron: false, showToggle: $faceIDEnabled)
                        MenuDivider()
                        NavigationLink {
                            Text("2FA Setup")
                                .navigationTitle("2FA")
                        } label: {
                            MenuRowView(icon: "lock.shield", title: "Two-Factor Authentication")
                        }
                        
                    }
                    .padding(.top, 0)
                    
                    MenuSection("Data") {
                        MenuRowView(title: "Share Analytics", showChevron: false, showToggle: $analyticsEnabled)
                        MenuDivider()
                        NavigationLink {
                            Text("Privacy Policy Content")
                                .navigationTitle("Privacy Policy")
                        } label: {
                            MenuRowView(icon: "hand.raised", title: "Data & Privacy Info")
                        }
                        
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            
            // Fixed Navigation Bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .frame(width: 44, height: 44)
                        .background((colorScheme == .dark ? Color.white : Color.black).opacity(0.05))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Privacy & Security")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Spacer()
                
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, AppSpacing.margin + AppSpacing.compact)
            .padding(.top, 16)
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Help Center
