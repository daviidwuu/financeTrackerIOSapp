import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct FinanceTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
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
    }
}
