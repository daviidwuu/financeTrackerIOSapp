import SwiftUI
import FirebaseCore
import FirebaseMessaging
import GoogleMobileAds
import RevenueCat

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        
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
    @AppStorage("premiumAppTheme") private var premiumAppTheme: String = "system"
    @StateObject private var appState = AppState.shared

    init() {
        if let apiKey = AppConfig.revenueCatAPIKey, !apiKey.isEmpty, apiKey != "REPLACE_WITH_PRODUCTION_KEY" {
            PurchaseManager.shared.configure(apiKey: apiKey)
        } else if let apiKey = AppConfig.revenueCatAPIKey, !apiKey.isEmpty, apiKey.hasPrefix("test_") {
            PurchaseManager.shared.configure(apiKey: apiKey)
        } else {
            DebugLogger.log("RevenueCat API key missing or placeholder. Set RevenueCatAPIKey/RevenueCatAPIKeyDebug in Info.plist.")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let figmaPreviewScreen = OnboardingFigmaScreen.current {
                    OnboardingFigmaPreviewHost(screen: figmaPreviewScreen)
                        .environmentObject(appState)
                        .preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))
                        .id("\(premiumAppTheme)-\(figmaPreviewScreen.rawValue)")
                } else if appState.isLoadingAuth {
                    // Launch Screen / Loading View
                    Color.backgroundPrimary
                        .ignoresSafeArea()
                } else if appState.isUserLoggedIn {
                    ContentView()
                        .environmentObject(appState)
                        .preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))
                        .id(premiumAppTheme) // Force redraw when custom theme changes
                    
                } else {
                    WelcomeView()
                        .environmentObject(appState)
                        .preferredColorScheme(userTheme == "system" ? nil : (userTheme == "dark" ? .dark : .light))
                        .id(premiumAppTheme) // Force redraw when custom theme changes
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
            .environmentObject(appState.userPremiumRepo)
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
                // Sync theme to widgets
                WidgetDataManager.shared.saveAppTheme(AppTheme(rawValue: premiumAppTheme) ?? .system)
                // Fetch Remote Config
                Task { await FirebaseManager.shared.fetchRemoteConfig() }
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
                // Backfill notification defaults for existing users who granted permission
                // but had all toggles off (pre-fix state)
                NotificationManager.shared.checkPermissionStatus { status in
                    if status == .authorized || status == .provisional {
                        NotificationManager.shared.enableDefaultNotificationPreferences()
                    } else if status == .notDetermined {
                        NotificationManager.shared.requestPermission { _ in }
                    }
                }
            }
    }
}
