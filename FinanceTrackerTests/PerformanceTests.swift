import XCTest
@testable import FinanceTracker

final class PerformanceTests: XCTestCase {

    override func setUpWithError() throws {
        // Clear caches before each test
        DebtCalculator.shared.clearCache()
    }

    override func tearDownWithError() throws {
    }

    func testDebtCalculatorPerformance() throws {
        // Generate a large number of balances to simulate a complex group
        var balances: [String: Double] = [:]
        for i in 0..<1000 {
            // Random balances between -500 and 500
            balances["User\(i)"] = Double.random(in: -500...500)
        }
        
        // Ensure net sum is roughly 0 by adjusting the first user
        let sum = balances.values.reduce(0, +)
        balances["User0"]! -= sum

        measure {
            // This will measure the time it takes to process 1000 users.
            // Run 1: Calculates
            // Run 2-10: Hits cache (simulating the UI re-render behavior)
            _ = DebtCalculator.shared.calculateDebtResolution(balances: balances)
        }
    }
}
