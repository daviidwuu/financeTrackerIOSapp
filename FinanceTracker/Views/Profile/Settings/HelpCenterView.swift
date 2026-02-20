import SwiftUI
import WidgetKit

struct HelpCenterView: View {
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
                    
                    MenuSection("FAQ") {
                        NavigationLink {
                            Text("Tap the + button on the home screen.")
                                .padding()
                                .navigationTitle("Adding Transactions")
                        } label: {
                            MenuRowView(icon: "plus.circle", title: "How to add a transaction?")
                        }
                        
                        
                        MenuDivider()
                        
                        NavigationLink {
                            Text("Go to the Wallet tab and tap + next to Budgets.")
                                .padding()
                                .navigationTitle("Setting Budgets")
                        } label: {
                            MenuRowView(icon: "chart.pie", title: "How to set a budget?")
                        }
                        
                        
                        MenuDivider()
                        
                        NavigationLink {
                            Text("Data export is coming soon.")
                                .padding()
                                .navigationTitle("Export Data")
                        } label: {
                            MenuRowView(icon: "square.and.arrow.up", title: "Exporting data")
                        }
                        
                    }
                    .padding(.top, 0)
                    
                    MenuSection("Contact") {
                        Button(action: { }) {
                            MenuRowView(icon: "envelope", title: "Contact Support")
                        }
                        
                        
                        MenuDivider()
                        
                        Button(action: { }) {
                            MenuRowView(icon: "ant", title: "Report a Bug")
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
                
                Text("Help Center")
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

// MARK: - About Us
