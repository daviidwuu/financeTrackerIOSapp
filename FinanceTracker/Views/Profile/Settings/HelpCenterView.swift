import SwiftUI
import WidgetKit
import StoreKit

struct HelpCenterView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @Environment(\.requestReview) var requestReview
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)
                    
                    MenuSection("FAQ") {
                        NavigationLink {
                            Text("Tap the + button on the home screen.")
                                .padding()
                                .navigationTitle("Adding Transactions")
                        } label: {
                            MenuRowView(icon: "plus.circle.fill", title: "How to add a transaction?", iconColor: .green)
                        }
                        
                        
                        MenuDivider()
                        
                        NavigationLink {
                            Text("Go to the Wallet tab and tap + next to Budgets.")
                                .padding()
                                .navigationTitle("Setting Budgets")
                        } label: {
                            MenuRowView(icon: "chart.pie.fill", title: "How to set a budget?", iconColor: .orange)
                        }
                        
                        
                        MenuDivider()
                        
                        NavigationLink {
                            Text("Data export is coming soon.")
                                .padding()
                                .navigationTitle("Export Data")
                        } label: {
                            MenuRowView(icon: "square.and.arrow.up.fill", title: "Exporting data", iconColor: .blue)
                        }
                        
                    }
                    .padding(.top, 0)
                    
                    MenuSection("Contact") {
                        Button(action: { 
                            HapticManager.shared.light()
                            if let url = URL(string: "mailto:support@wym.app") {
                                openURL(url)
                            }
                        }) {
                            MenuRowView(icon: "envelope.fill", title: "Contact Support", iconColor: .purple)
                        }
                        
                        MenuDivider()
                        
                        Button(action: { 
                            HapticManager.shared.light()
                            if let url = URL(string: "mailto:bugs@wym.app") {
                                openURL(url)
                            }
                        }) {
                            MenuRowView(icon: "ant.fill", title: "Report a Bug", iconColor: .red)
                        }
                        
                    }
                    
                    MenuSection("About") {
                        MenuRowView(icon: "person.fill", title: "Developer", value: "David Wu", showChevron: false, iconColor: .indigo)
                        
                        MenuDivider()
                        
                        Button(action: { 
                            HapticManager.shared.light()
                            requestReview()
                        }) {
                            MenuRowView(icon: "star.fill", title: "Rate App", showChevron: true, iconColor: .yellow)
                        }
                        
                        
                        MenuDivider()
                        
                        Button(action: { HapticManager.shared.light();  showTerms = true }) {
                            MenuRowView(icon: "doc.text.fill", title: "Terms of Use (EULA)", showChevron: true, iconColor: .gray)
                        }
                        
                        
                        MenuDivider()
                        
                        Button(action: { HapticManager.shared.light();  showPrivacy = true }) {
                            MenuRowView(icon: "hand.raised.fill", title: "Privacy Policy", showChevron: true, iconColor: .blue)
                        }
                        
                    }
                    
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("wym")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(AppConfig.versionDisplayString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
        }
        .overlayHeader(.navigation(title: "Support & About", onBack: { dismiss() }))
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showTerms) {
            LegalDocumentView(document: .terms)
        }
        .sheet(isPresented: $showPrivacy) {
            LegalDocumentView(document: .privacy)
        }
    }
}

// MARK: - About Us
