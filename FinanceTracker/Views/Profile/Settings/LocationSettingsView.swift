import SwiftUI
import CoreLocation

struct LocationSettingsView: View {
    @AppStorage("isLocationEnabled") private var isLocationEnabled: Bool = true
    @ObservedObject private var locationManager = LocationManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var authStatus: CLAuthorizationStatus = .notDetermined
    @State private var showingSettingsAlert = false
    
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ScrollOffsetTracker()
                    Spacer().frame(height: 60)
                    
                    // System Permission Section
                    MenuSection("System Permission") {
                        MenuControlRow(
                            icon: permissionIcon,
                            iconColor: permissionColor,
                            title: "Location Access",
                            subtitle: permissionText
                        ) {
                            if authStatus == .notDetermined {
                                Button("Enable") {
                                    HapticManager.shared.light()
                                    locationManager.requestPermission()
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(AppRadius.small)
                            } else if authStatus == .denied || authStatus == .restricted {
                                Button("Settings") {
                                    HapticManager.shared.light()
                                    showingSettingsAlert = true
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.orange.opacity(0.1))
                                .foregroundColor(.orange)
                                .cornerRadius(AppRadius.small)
                            }
                        }
                    }
                    .padding(.top, 0)
                    
                    // App Settings Section
                    MenuSection("App Settings") {
                        MenuRowView(
                            icon: "mappin.and.ellipse",
                            title: "Use Location for Transactions",
                            showChevron: false,
                            showToggle: $isLocationEnabled
                        )
                    }
                    
                    Text("When enabled, your current location is attached to new transactions for spending insights.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, AppSpacing.margin + 12)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
        }
        .overlayHeader(.navigation(title: "Location", onBack: { dismiss() }))
        .navigationBarBackButtonHidden(true)
        .onAppear {
            authStatus = locationManager.authorizationStatus
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            authStatus = locationManager.authorizationStatus
        }
        .alert("Open Settings", isPresented: $showingSettingsAlert) {
            Button("Cancel", role: .cancel) { HapticManager.shared.light() }
            Button("Settings") {
                HapticManager.shared.light()
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("To enable location services, please allow them in Settings.")
        }
    }
    
    // MARK: - Permission Helpers
    
    private var permissionIcon: String {
        switch authStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return "location.fill"
        case .denied, .restricted:
            return "location.slash.fill"
        default:
            return "location.circle.fill"
        }
    }
    
    private var permissionColor: Color {
        switch authStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        case .denied, .restricted:
            return .red
        default:
            return .orange
        }
    }
    
    private var permissionText: String {
        switch authStatus {
        case .authorizedWhenInUse:
            return "While Using the App"
        case .authorizedAlways:
            return "Always"
        case .denied:
            return "Location denied"
        case .restricted:
            return "Location restricted"
        case .notDetermined:
            return "Not requested yet"
        @unknown default:
            return "Unknown status"
        }
    }
}
