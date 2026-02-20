import SwiftUI
import WidgetKit

struct AboutView: View {
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
                    
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .padding(.top, 20)
                        
                        Text("wym")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Version 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    MenuSection {
                        HStack {
                            Text("Developer")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("David Wu")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        
                        MenuDivider()
                        
                        HStack {
                            Text("Website")
                                .font(.body)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("example.com")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 0)
                    
                    MenuSection {
                        Button(action: {}) {
                            MenuRowView(title: "Rate App", showChevron: true)
                        }
                        
                        
                        MenuDivider()
                        
                        Button(action: {}) {
                            MenuRowView(title: "Terms of Service", showChevron: true)
                        }
                        
                        
                        MenuDivider()
                        
                        Button(action: {}) {
                            MenuRowView(title: "Privacy Policy", showChevron: true)
                        }
                        
                    }
                    
                    Spacer()
                }
                .padding(.top, 10)
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
                
                Text("About Us")
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
