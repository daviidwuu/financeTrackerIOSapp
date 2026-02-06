import SwiftUI

struct LocationSettingsView: View {
    @AppStorage("isLocationEnabled") private var isLocationEnabled: Bool = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MenuSection("Tracking") {
                    MenuRowView(title: "Attach Location to Transactions", showChevron: false, showToggle: $isLocationEnabled)
                }
                
                MenuSection(nil) {
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Text("Open System Settings")
                                .font(.body)
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                }
                
                Text("When enabled, the app will attempt to save the location where you added the transaction. You can manage precise permissions in iOS Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 20)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Location Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        LocationSettingsView()
    }
}
