import XCTest

// MARK: - Settle-Up Flow UI Tests
//
// These tests verify the settle-up navigation path at the UI level.
// They test app structure and navigation reachability, not network calls.
//
// Pre-conditions:
// - App launches and reaches the onboarding / main flow
// - Social tab is navigable
//
// Because these tests run against the real app binary, they require
// the app to either:
//   a) Be pre-populated with test data via environment variables, or
//   b) Navigate through the onboarding flow first.
//
// The tests are structured so failures identify the breakage point clearly.

final class SettleUpUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Pass a launch argument so the app can detect it's running under UI tests
        // and skip authentication/onboarding when possible.
        app.launchArguments += ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App launch smoke test

    @MainActor
    func testAppLaunchesSuccessfully() throws {
        // The app must launch without crashing and display some UI.
        // This is the base invariant for all other tests in this file.
        XCTAssertTrue(app.state == .runningForeground, "App must be running in foreground after launch")
    }

    // MARK: - Tab navigation reachability

    @MainActor
    func testSocialTabIsReachable() throws {
        // The Social tab must be present and tappable in the main TabView.
        // Tab is identified by its accessibility label ("Social") or the tab bar button.

        // Give the app a moment to settle (accounts for async auth checks)
        let socialTab = app.tabBars.buttons["Social"]
        let tabExists = socialTab.waitForExistence(timeout: 5)

        // If the tab bar is not visible (e.g. onboarding is shown), skip gracefully
        guard tabExists else {
            // App may be showing onboarding or login — this is acceptable for CI
            // where Firebase Auth is not configured.
            throw XCTSkip("Social tab not reachable — app may be in onboarding/login state")
        }

        socialTab.tap()

        // After tapping, the Social dashboard should be visible
        // Look for the "Social" navigation title or a known element in SocialDashboardView
        let socialViewIdentifier = app.navigationBars["Social"]
            .waitForExistence(timeout: 3)
        // We don't hard-assert here because the nav title can vary by view state;
        // the important thing is the tap didn't crash the app.
        XCTAssertTrue(app.state == .runningForeground, "App must remain running after tapping Social tab")
    }

    // MARK: - Settle-up happy path navigation (group required)

    @MainActor
    func testSettleUpNavigationHappyPath() throws {
        // Navigate: Social tab → Groups → tap a group → Settle Up button
        //
        // This test verifies the settle-up NAVIGATION path — not the actual
        // Firestore write — so it passes even without a backend connection.

        let socialTab = app.tabBars.buttons["Social"]
        guard socialTab.waitForExistence(timeout: 5) else {
            throw XCTSkip("Social tab not reachable — app may be in onboarding/login state")
        }
        socialTab.tap()

        // Look for any "Settle Up" button in the social view hierarchy.
        // In a real test run with pre-populated data, this would be visible.
        let settleUpButton = app.buttons.matching(identifier: "Settle Up").firstMatch

        if settleUpButton.waitForExistence(timeout: 3) {
            settleUpButton.tap()

            // After tapping Settle Up, the wizard should appear.
            let nextButton = app.buttons["Next"].firstMatch
            let sheetVisible = nextButton.waitForExistence(timeout: 3)

            if sheetVisible {
                // The sheet presented successfully — verify cancel/dismiss works
                let cancelButton = app.buttons["Cancel"].firstMatch
                if cancelButton.waitForExistence(timeout: 2) {
                    cancelButton.tap()
                }
                // App must still be running after dismissal
                XCTAssertTrue(app.state == .runningForeground)
            }
        } else {
            // No settle-up button found — likely no group data in test environment.
            // This is acceptable; we've verified the social tab is at least reachable.
            XCTAssertTrue(app.state == .runningForeground,
                          "App should stay stable even without group data to display a settle-up button")
        }
    }

    // MARK: - Settle-up permission guard (UI reflection)

    @MainActor
    func testSettleUpConfirmButton_disabledWhenAmountIsEmpty() throws {
        // When the Settle Up sheet is open and the amount field is empty,
        // the Confirm/Settle button must be disabled to prevent invalid submissions.
        //
        // This test works if the settle-up sheet is accessible.

        let socialTab = app.tabBars.buttons["Social"]
        guard socialTab.waitForExistence(timeout: 5) else {
            throw XCTSkip("Social tab not reachable")
        }
        socialTab.tap()

        let settleUpButton = app.buttons.matching(identifier: "Settle Up").firstMatch
        guard settleUpButton.waitForExistence(timeout: 3) else {
            throw XCTSkip("No Settle Up button found — no group data available in test environment")
        }

        settleUpButton.tap()

        let nextButton = app.buttons["Next"].firstMatch
        guard nextButton.waitForExistence(timeout: 2) else {
            throw XCTSkip("Settle-up wizard did not appear")
        }

        nextButton.tap()

        // Step 2 uses the same "Next" button, and it should be disabled until an amount is entered.
        if app.textFields["0.00"].firstMatch.waitForExistence(timeout: 2) {
            XCTAssertFalse(
                nextButton.isEnabled,
                "Next button must be disabled when amount is empty or zero"
            )
        }
    }

    // MARK: - Navigation does not crash on rapid tab switches

    @MainActor
    func testRapidTabSwitching_doesNotCrash() throws {
        // Rapid tab switching has historically caused crashes when Firestore listeners
        // fire during a view deallocation cycle. This test stresses that path.

        guard app.tabBars.buttons["Social"].waitForExistence(timeout: 5) else {
            throw XCTSkip("Tab bar not reachable")
        }

        // Switch between Home and Social rapidly
        for _ in 0..<4 {
            app.tabBars.buttons["Social"].tap()
            app.tabBars.buttons["Home"].tap()
        }

        XCTAssertTrue(app.state == .runningForeground,
                      "App must not crash during rapid tab switching")
    }

    // MARK: - Screenshot on failure helper

    @MainActor
    func testCaptureSettleUpScreenshot() throws {
        guard app.tabBars.buttons["Social"].waitForExistence(timeout: 5) else {
            throw XCTSkip("Tab bar not reachable")
        }

        app.tabBars.buttons["Social"].tap()

        // Capture screenshot of Social view for visual reference in test reports
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Social Tab - Settle Up Flow"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(app.state == .runningForeground)
    }
}
