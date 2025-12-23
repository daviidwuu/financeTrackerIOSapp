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
    @AppStorage("isDarkMode") private var isDarkMode = false
    @StateObject private var appState = AppState.shared

    init() {}

    var body: some Scene {
        WindowGroup {
            if appState.isUserLoggedIn {
                ContentView()
                    .environmentObject(appState)
                    .preferredColorScheme(isDarkMode ? .dark : .light)
                    .onAppear {
                        // Start listening for transactions added via shortcuts
                        if !appState.currentUserId.isEmpty {
                            NotificationManager.shared.startListeningForShortcutTransactions(userId: appState.currentUserId)
                        }
                    }
            } else {
                WelcomeView()
                    .environmentObject(appState)
                    .preferredColorScheme(isDarkMode ? .dark : .light)
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                // Clear badge when app is opened
                NotificationManager.shared.clearBadge()
            case .background:
                // Schedule background refresh if enabled
                NotificationManager.shared.scheduleDailySummary()
            default:
                break
            }
        }
    }
}
