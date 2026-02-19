import SwiftUI
import CoreLocation
import Combine

struct LocationSettingsView: View {
    @AppStorage("isLocationEnabled") private var isLocationEnabled: Bool = true
    @Environment(\.colorScheme) var colorScheme
    @State private var permissionStatus: CLAuthorizationStatus = .notDetermined
    
    // Timer to poll status
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Permission Status Section
                MenuSection("System Permission") {
                    HStack {
                         Image(systemName: permissionIcon)
                             .foregroundColor(permissionColor)
                         VStack(alignment: .leading, spacing: 4) {
                             Text("Location Access")
                                 .font(.subheadline)
                                 .fontWeight(.semibold)
                             Text(permissionText)
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                         }
                         Spacer()
                         if permissionStatus == .notDetermined {
                             Button("Enable") {
                                 LocationManager.shared.requestPermission()
                             }
                             .font(.caption)
                             .fontWeight(.semibold)
                             .padding(.vertical, 6)
                             .padding(.horizontal, 12)
                             .background(Color.blue.opacity(0.1))
                             .foregroundColor(.blue)
                             .cornerRadius(AppRadius.small)
                         } else if permissionStatus == .denied {
                             Button("Settings") {
                                 if let url = URL(string: UIApplication.openSettingsURLString) {
                                     UIApplication.shared.open(url)
                                 }
                             }
                             .font(.caption)
                             .fontWeight(.semibold)
                             .padding(.vertical, 6)
                             .padding(.horizontal, 12)
                             .background(AppColors.functionalExpense.opacity(0.1))
                             .foregroundColor(.red)
                             .cornerRadius(AppRadius.small)
                         }
                     }
                     .padding(AppSpacing.element)
                }
                
                MenuSection("App Settings") {
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
        .onAppear {
            checkStatus()
        }
        .onReceive(timer) { _ in
            checkStatus()
        }
    }
    
    private func checkStatus() {
        permissionStatus = LocationManager.shared.authorizationStatus
    }
    
    private var permissionIcon: String {
        switch permissionStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var permissionColor: Color {
        switch permissionStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        default:
            return .orange
        }
    }
    
    private var permissionText: String {
        switch permissionStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Allowed"
        case .denied, .restricted:
            return "Denied"
        case .notDetermined:
            return "Not requested yet"
        @unknown default:
            return "Unknown"
        }
    }
}

#Preview {
    NavigationView {
        LocationSettingsView()
    }
}
