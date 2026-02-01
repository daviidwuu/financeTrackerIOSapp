import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        // Initialize NotificationManager to set delegate
        let manager = NotificationManager.shared
        manager.registerBackgroundTasks()
        return true
    }
}

@main
struct FinanceTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) var scenePhase
    @AppStorage("userTheme") private var userTheme: String = "system"
    @StateObject private var appState = AppState.shared

    init() {}

    var body: some Scene {
        WindowGroup {
            if appState.isUserLoggedIn {
                ContentView()
                    .environmentObject(appState)
                    .preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))

            } else {
                WelcomeView()
                    .environmentObject(appState)
                    .preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // Clear badge when app is opened
                NotificationManager.shared.clearBadge()
                // Check location for Travel Mode
                LocationManager.shared.checkLocation()
            case .background:
                // Schedule background refresh if enabled
                NotificationManager.shared.scheduleDailySummary()
            default:
                break
            }
        }
    }
}
