import SwiftUI

struct LocationSettingsView: View {
    @AppStorage("isLocationEnabled") private var isLocationEnabled: Bool = true
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Form {
            Section(header: Text("Tracking")) {
                Toggle("Attach Location to Transactions", isOn: $isLocationEnabled)
            }
            .listRowBackground(Color(UIColor.secondarySystemBackground))
            
            Section(footer: Text("When enabled, the app will attempt to save the location where you added the transaction. You can manage precise permissions in iOS Settings.")) {
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Text("Open System Settings")
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }
            .listRowBackground(Color(UIColor.secondarySystemBackground))
        }
        .navigationTitle("Location Settings")
        .background(Color.listBackground)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    NavigationView {
        LocationSettingsView()
    }
}
