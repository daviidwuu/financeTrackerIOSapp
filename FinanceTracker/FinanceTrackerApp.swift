import SwiftUI
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Push Notifications
        Messaging.messaging().delegate = NotificationManager.shared
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        // Register
        application.registerForRemoteNotifications()
        
        // Initialize NotificationManager to set delegate
        let manager = NotificationManager.shared
        manager.registerBackgroundTasks()
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DebugLogger.log("Failed to register for remote notifications: \(error)")
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
            ZStack {
                if appState.isLoadingAuth {
                    // Launch Screen / Loading View
                    Color.backgroundPrimary
                        .ignoresSafeArea()
                } else if appState.isUserLoggedIn {
                    ContentView()
                        .environmentObject(appState)
                        .preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))
                    
                } else {
                    WelcomeView()
                        .environmentObject(appState)
                        .preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))
                }
            }
            .environmentObject(appState.transactionRepo)
            .environmentObject(appState.budgetRepo)
            .environmentObject(appState.recurringRepo)
            .environmentObject(appState.savingGoalRepo)
            .environmentObject(appState.requestRepo)
            .environmentObject(appState.groupRepo)
            .environmentObject(appState.friendRepo)
            .environmentObject(appState.friendRequestRepo)
            .environmentObject(appState.groupInvitationRepo)
            .environmentObject(appState.guestRepo)
            .onOpenURL { url in
                // Handle Widget Deep Link
                if url.scheme == "wym" && url.host == "widget-launch" {
                    GamificationManager.shared.completeMission(id: "widget_watcher")
                }
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
        .onChange(of: appState.isUserLoggedIn) { _, isLoggedIn in
                guard isLoggedIn else { return }
                NotificationManager.shared.syncTokenWithServer()
                MigrationManager.shared.checkForMigrations()
            }
    }
}
