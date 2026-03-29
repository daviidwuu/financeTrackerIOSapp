import SwiftUI
import Combine

/// Owns all runtime navigation and modal-presentation state for the app.
/// Keeping this separate from AppState ensures that business-logic classes
/// (NotificationManager, AppState itself) can mutate navigation without
/// dragging in the full authentication / repository graph.
class AppNavigationState: ObservableObject {

    // MARK: - Tab Selection
    /// The currently visible main tab (0 = Home, 1 = Social, 2 = Wallet).
    @Published var selectedTab: Int = 0

    // MARK: - Profile / Settings Navigation
    // Note: showProfile is kept on AppState as @Published because HomeView binds
    // to it via `$appState.showProfile`. Only shouldOpenCurrencySettings (write-only
    // from NotificationManager, no binding) lives here.
    /// When true, navigates directly to the Currency Settings sub-screen inside Profile.
    @Published var shouldOpenCurrencySettings: Bool = false

    // MARK: - Deep-Link Driven Sheets
    /// Controls presentation of the Daily Summary transaction list.
    @Published var showDailySummary: Bool = false
    /// The date that the Daily Summary should display when it opens.
    @Published var dailySummaryDate: Date?

    // MARK: - Report Sheets
    /// Controls presentation of the Weekly Report sheet.
    @Published var showWeeklyReport: Bool = false

    // MARK: - Singleton
    static let shared = AppNavigationState()
    private init() {}
}
